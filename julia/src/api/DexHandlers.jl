# julia/src/api/DexHandlers.jl
module DexHandlers

using HTTP, Logging, Dates
using ..Utils # For standardized responses
import ..framework.JuliaOSFramework.DEX
import ..framework.JuliaOSFramework.DEXBase

# Helper to get/create DEX instance - similar to PriceFeedHandlers
# This needs a robust way to manage DEX configurations (e.g., from a DB or config file)
const CONFIGURED_DEX_INSTANCES = Dict{String, DEXBase.AbstractDEX}() # Cache key: "protocol-version-configname"
const DEX_INSTANCES_LOCK = ReentrantLock()

function _get_or_create_dex_instance(protocol::String, version::String, params::Dict)::Union{DEXBase.AbstractDEX, Nothing}
    # Simplified instance management. In production, configs would be pre-loaded.
    # Key could be protocol_version_chainId_dexName for more uniqueness.
    dex_name_param = get(params, "dex_name", protocol) # Use protocol as default dex_name if not provided
    chain_id_param = get(params, "chain_id", "1") # Default to Ethereum mainnet string
    
    instance_key = "$(lowercase(protocol))-$(lowercase(version))-$(dex_name_param)-$(chain_id_param)"

    lock(DEX_INSTANCES_LOCK) do
        if haskey(CONFIGURED_DEX_INSTANCES, instance_key)
            return CONFIGURED_DEX_INSTANCES[instance_key]
        end

        # Create a DEXConfig from params. These should ideally come from a secure app config.
        # Ensure chain_id is Int
        parsed_chain_id = tryparse(Int, chain_id_param)
        if isnothing(parsed_chain_id)
            @error "Invalid chain_id format: $chain_id_param. Must be an integer."
            return nothing # Or throw specific error
        end

        dex_config_params = Dict{Symbol, Any}(
            :name => dex_name_param, 
            :chain_id => parsed_chain_id,
            :rpc_url => get(params, "rpc_url", "https://mainnet.infura.io/v3/YOUR_KEY"), 
            :router_address => get(params, "router_address", ""),
            :factory_address => get(params, "factory_address", ""),
            # private_key should NOT be passed via API for security. Wallet interactions should be separate.
        )
        
        try
            config = DEXBase.DEXConfig(;dex_config_params...)
            instance = DEX.create_dex_instance(protocol, version, config)
            CONFIGURED_DEX_INSTANCES[instance_key] = instance
            return instance
        catch e
            @error "Failed to create DEX instance for $protocol $version" error=e params=params
            return nothing
        end
    end
end

function list_dex_protocols_handler(req::HTTP.Request)
    try
        protocols = DEX.list_available_dex_protocols()
        return Utils.json_response(Dict("available_protocols" => protocols))
    catch e
        @error "Error in list_dex_protocols_handler" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to list DEX protocols", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

function get_dex_pairs_handler(req::HTTP.Request, protocol::String, version::String)
    query_params = Dict(pairs(HTTP.queryparams(HTTP.URI(req.target))))
    limit = tryparse(Int, get(query_params, "limit", "100")) !== nothing ? parse(Int, get(query_params, "limit", "100")) : 100

    dex_instance = _get_or_create_dex_instance(protocol, version, query_params)
    if isnothing(dex_instance)
        return Utils.error_response("DEX '$protocol $version' not found or failed to initialize.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND, details=Dict("protocol"=>protocol, "version"=>version))
    end

    try
        pairs_list = DEXBase.get_pairs(dex_instance, limit=limit)
        result = [
            Dict("id"=>p.id, 
                 "token0"=>Dict("symbol"=>p.token0.symbol, "address"=>p.token0.address, "decimals"=>p.token0.decimals),
                 "token1"=>Dict("symbol"=>p.token1.symbol, "address"=>p.token1.address, "decimals"=>p.token1.decimals),
                 "fee"=>p.fee, "protocol_name"=>p.protocol) 
            for p in pairs_list
        ]
        return Utils.json_response(Dict("protocol"=>protocol, "version"=>version, "pairs"=>result))
    catch e
        @error "Error getting pairs for $protocol $version" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to get pairs for $protocol $version: $(sprint(showerror, e))", 500, error_code=Utils.ERROR_CODE_EXTERNAL_SERVICE_ERROR)
    end
end

function get_dex_price_handler(req::HTTP.Request, protocol::String, version::String)
    query_params = Dict(pairs(HTTP.queryparams(HTTP.URI(req.target))))
    token0_symbol_or_addr = get(query_params, "token0", "") 
    token1_symbol_or_addr = get(query_params, "token1", "") 
    
    if isempty(token0_symbol_or_addr) || isempty(token1_symbol_or_addr)
        return Utils.error_response("Missing 'token0' or 'token1' (symbol or address) query parameters.", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT)
    end

    dex_instance = _get_or_create_dex_instance(protocol, version, query_params)
    if isnothing(dex_instance)
        return Utils.error_response("DEX '$protocol $version' not found or failed to initialize.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
    end

    try
        all_pairs = DEXBase.get_pairs(dex_instance) # This might be inefficient if many pairs
        target_pair = nothing
        
        # Try to match by symbol first, then by address if symbols don't match or are ambiguous
        # This logic can be complex if symbols are not unique or if addresses are preferred.
        for p in all_pairs
            is_token0_match_sym = uppercase(p.token0.symbol) == uppercase(token0_symbol_or_addr)
            is_token1_match_sym = uppercase(p.token1.symbol) == uppercase(token1_symbol_or_addr)
            is_token0_match_addr = lowercase(p.token0.address) == lowercase(token0_symbol_or_addr)
            is_token1_match_addr = lowercase(p.token1.address) == lowercase(token1_symbol_or_addr)

            if (is_token0_match_sym || is_token0_match_addr) && (is_token1_match_sym || is_token1_match_addr)
                target_pair = p
                break
            end
            # Check for flipped pair
            if (is_token0_match_sym || is_token0_match_addr) && (uppercase(p.token1.symbol) == uppercase(token0_symbol_or_addr) || lowercase(p.token1.address) == lowercase(token0_symbol_or_addr)) &&
               (uppercase(p.token0.symbol) == uppercase(token1_symbol_or_addr) || lowercase(p.token0.address) == lowercase(token1_symbol_or_addr))
                target_pair = p # Matched but flipped
                # We'll handle the price inversion later
                break
            end
        end

        if isnothing(target_pair)
            return Utils.error_response("Pair $token0_symbol_or_addr/$token1_symbol_or_addr not found on $protocol $version.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
        end
        
        price_of_token0_in_token1 = DEXBase.get_price(dex_instance, target_pair) # This is price of target_pair.token0 in terms of target_pair.token1

        # Determine if we need to invert the price based on requested order
        final_price = if (uppercase(target_pair.token0.symbol) == uppercase(token0_symbol_or_addr) || lowercase(target_pair.token0.address) == lowercase(token0_symbol_or_addr))
            price_of_token0_in_token1 # Requested token0 is pair's token0
        else
            # Requested token0 is pair's token1, so we need price of token1 in terms of token0
            price_of_token0_in_token1 == 0.0 ? 0.0 : 1.0 / price_of_token0_in_token1 
        end

        return Utils.json_response(Dict(
            "protocol"=>protocol, "version"=>version,
            "base_asset"=>token0_symbol_or_addr, # What was requested as base
            "quote_asset"=>token1_symbol_or_addr, # What was requested as quote
            "price"=>final_price, 
            "timestamp"=>string(now(UTC))
        ))
    catch e
        @error "Error getting price for $protocol $version, $token0_symbol_or_addr/$token1_symbol_or_addr" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to get price: $(sprint(showerror, e))", 500, error_code=Utils.ERROR_CODE_EXTERNAL_SERVICE_ERROR)
    end
end

function get_dex_liquidity_handler(req::HTTP.Request, protocol::String, version::String)
    query_params = Dict(pairs(HTTP.queryparams(HTTP.URI(req.target))))
    token0_symbol_or_addr = get(query_params, "token0", "") 
    token1_symbol_or_addr = get(query_params, "token1", "") 

    if isempty(token0_symbol_or_addr) || isempty(token1_symbol_or_addr)
        return Utils.error_response("Missing 'token0' or 'token1' (symbol or address) query parameters for liquidity.", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT)
    end

    dex_instance = _get_or_create_dex_instance(protocol, version, query_params)
    if isnothing(dex_instance)
        return Utils.error_response("DEX '$protocol $version' not found or failed to initialize.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
    end

    try
        # Find the DEXPair (similar to get_dex_price_handler)
        all_pairs = DEXBase.get_pairs(dex_instance)
        target_pair = nothing
        for p in all_pairs
            is_t0_match = uppercase(p.token0.symbol) == uppercase(token0_symbol_or_addr) || lowercase(p.token0.address) == lowercase(token0_symbol_or_addr)
            is_t1_match = uppercase(p.token1.symbol) == uppercase(token1_symbol_or_addr) || lowercase(p.token1.address) == lowercase(token1_symbol_or_addr)
            if is_t0_match && is_t1_match
                target_pair = p
                break
            end
             # Check for flipped pair (though liquidity order usually doesn't matter as much as price)
            if (uppercase(p.token0.symbol) == uppercase(token1_symbol_or_addr) || lowercase(p.token0.address) == lowercase(token1_symbol_or_addr)) &&
               (uppercase(p.token1.symbol) == uppercase(token0_symbol_or_addr) || lowercase(p.token1.address) == lowercase(token0_symbol_or_addr))
                target_pair = p 
                break
            end
        end

        if isnothing(target_pair)
            return Utils.error_response("Pair $token0_symbol_or_addr/$token1_symbol_or_addr not found on $protocol $version for liquidity check.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
        end
        
        liquidity_token0, liquidity_token1 = DEXBase.get_liquidity(dex_instance, target_pair)
        
        return Utils.json_response(Dict(
            "protocol"=>protocol, "version"=>version,
            "pair_id"=>target_pair.id,
            "token0_symbol"=>target_pair.token0.symbol, 
            "token0_liquidity"=>liquidity_token0,
            "token1_symbol"=>target_pair.token1.symbol,
            "token1_liquidity"=>liquidity_token1,
            "timestamp"=>string(now(UTC))
        ))
    catch e
        @error "Error getting liquidity for $protocol $version, $token0_symbol_or_addr/$token1_symbol_or_addr" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to get liquidity: $(sprint(showerror, e))", 500, error_code=Utils.ERROR_CODE_EXTERNAL_SERVICE_ERROR)
    end
end

function create_dex_order_handler(req::HTTP.Request, protocol::String, version::String)
    body = Utils.parse_request_body(req)
    if isnothing(body) || !isa(body, Dict)
        return Utils.error_response("Request body must be a valid JSON object for order creation.", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT)
    end

    # Required fields: pair_id (or token0/token1 symbols/addresses), order_type, side, amount
    # Optional: price (for limit orders)
    pair_id = get(body, "pair_id", "")
    token0_str = get(body, "token0", "") # Symbol or address
    token1_str = get(body, "token1", "") # Symbol or address
    order_type_str = get(body, "order_type", "") # "MARKET", "LIMIT"
    side_str = get(body, "side", "")         # "BUY", "SELL"
    amount = get(body, "amount", 0.0)
    price = get(body, "price", 0.0)         # For limit orders

    if (isempty(pair_id) && (isempty(token0_str) || isempty(token1_str))) || isempty(order_type_str) || isempty(side_str) || amount <= 0
        return Utils.error_response("Missing required fields for order: (pair_id or token0/token1), order_type, side, amount.", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT)
    end
    
    query_params = Dict(pairs(HTTP.queryparams(HTTP.URI(req.target)))) # For dex instance config
    dex_instance = _get_or_create_dex_instance(protocol, version, query_params)
    if isnothing(dex_instance)
        return Utils.error_response("DEX '$protocol $version' not found or failed to initialize.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
    end

    try
        target_pair::Union{DEXBase.DEXPair, Nothing} = nothing
        if !isempty(pair_id)
            # Find pair by ID (more robust if IDs are unique across DEX instances or qualified)
            all_pairs = DEXBase.get_pairs(dex_instance)
            idx = findfirst(p -> p.id == pair_id, all_pairs)
            if !isnothing(idx) target_pair = all_pairs[idx] end
        elseif !isempty(token0_str) && !isempty(token1_str)
            all_pairs = DEXBase.get_pairs(dex_instance)
            for p in all_pairs
                is_t0 = uppercase(p.token0.symbol) == uppercase(token0_str) || lowercase(p.token0.address) == lowercase(token0_str)
                is_t1 = uppercase(p.token1.symbol) == uppercase(token1_str) || lowercase(p.token1.address) == lowercase(token1_str)
                if is_t0 && is_t1 target_pair = p; break; end
                # Check flipped
                if (uppercase(p.token0.symbol) == uppercase(token1_str) || lowercase(p.token0.address) == lowercase(token1_str)) &&
                   (uppercase(p.token1.symbol) == uppercase(token0_str) || lowercase(p.token1.address) == lowercase(token0_str))
                    target_pair = p; break; 
                end
            end
        end

        if isnothing(target_pair)
            return Utils.error_response("Pair not found for order creation (id: '$pair_id', tokens: '$token0_str/$token1_str').", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
        end

        order_type_enum = try Symbol(uppercase(order_type_str)) catch; return Utils.error_response("Invalid order_type.", 400) end
        if !(order_type_enum in instances(DEXBase.OrderType)) return Utils.error_response("Invalid order_type.", 400) end
        
        side_enum = try Symbol(uppercase(side_str)) catch; return Utils.error_response("Invalid side.", 400) end
        if !(side_enum in instances(DEXBase.OrderSide)) return Utils.error_response("Invalid side.", 400) end

        dex_order = DEXBase.create_order(dex_instance, target_pair, DEXBase.OrderType(Int(Val(order_type_enum))), DEXBase.OrderSide(Int(Val(side_enum))), amount, price)
        
        # Convert DEXOrder to Dict for JSON response
        order_dict = Dict(
            "order_id" => dex_order.id,
            "pair_id" => dex_order.pair.id,
            "type" => string(dex_order.type),
            "side" => string(dex_order.side),
            "amount" => dex_order.amount,
            "price" => dex_order.price,
            "status" => string(dex_order.status),
            "timestamp" => string(unix2datetime(dex_order.timestamp)),
            "tx_hash" => dex_order.tx_hash,
            "metadata" => dex_order.metadata
        )
        return Utils.json_response(order_dict, 201) # 201 Created (or 202 Accepted if async)
    catch e
        @error "Error creating DEX order on $protocol $version" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to create DEX order: $(sprint(showerror, e))", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

function get_dex_order_status_handler(req::HTTP.Request, protocol::String, version::String, order_id::String)
    if isempty(order_id)
        return Utils.error_response("Order ID cannot be empty.", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT)
    end
    query_params = Dict(pairs(HTTP.queryparams(HTTP.URI(req.target))))
    dex_instance = _get_or_create_dex_instance(protocol, version, query_params)
    if isnothing(dex_instance)
        return Utils.error_response("DEX '$protocol $version' not found or failed to initialize.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
    end

    try
        dex_order = DEXBase.get_order_status(dex_instance, order_id)
        # Assuming get_order_status returns a DEXOrder or throws if not found by underlying module
        # If it can return nothing for "not found", need to handle that.
        # For now, assuming it returns a valid DEXOrder or errors.
        order_dict = Dict(
            "order_id" => dex_order.id,
            "pair_id" => dex_order.pair.id, # This might be problematic if pair is mock in placeholder
            "type" => string(dex_order.type),
            "side" => string(dex_order.side),
            "amount" => dex_order.amount,
            "price" => dex_order.price,
            "status" => string(dex_order.status),
            "timestamp" => string(unix2datetime(dex_order.timestamp)),
            "tx_hash" => dex_order.tx_hash,
            "metadata" => dex_order.metadata
        )
        return Utils.json_response(order_dict)
    catch e
        # Check if error indicates order not found by the DEX module
        if occursin("not found", lowercase(sprint(showerror, e))) # Basic check
            return Utils.error_response("Order '$order_id' not found on $protocol $version.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
        end
        @error "Error getting DEX order status for $order_id on $protocol $version" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to get DEX order status: $(sprint(showerror, e))", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

function cancel_dex_order_handler(req::HTTP.Request, protocol::String, version::String, order_id::String)
    if isempty(order_id)
        return Utils.error_response("Order ID cannot be empty.", 400, error_code=Utils.ERROR_CODE_INVALID_INPUT)
    end
    query_params = Dict(pairs(HTTP.queryparams(HTTP.URI(req.target))))
    dex_instance = _get_or_create_dex_instance(protocol, version, query_params)
    if isnothing(dex_instance)
        return Utils.error_response("DEX '$protocol $version' not found or failed to initialize.", 404, error_code=Utils.ERROR_CODE_NOT_FOUND)
    end

    try
        # Note: DEXBase.cancel_order in UniswapDEX.jl is a placeholder and likely returns false.
        # A real implementation would depend on the DEX's capabilities (e.g., for limit order books).
        success = DEXBase.cancel_order(dex_instance, order_id)
        if success
            return Utils.json_response(Dict("message" => "Order '$order_id' cancellation request processed.", "order_id" => order_id, "cancellation_successful" => true))
        else
            # Could be because order doesn't exist, is already filled/cancelled, or not cancellable.
            # The underlying module should ideally provide more specific reasons.
            return Utils.error_response("Failed to cancel order '$order_id' on $protocol $version. It may not exist, be already finalized, or not be cancellable.", 400, error_code="ORDER_CANCELLATION_FAILED")
        end
    catch e
        @error "Error cancelling DEX order $order_id on $protocol $version" exception=(e, catch_backtrace())
        return Utils.error_response("Failed to cancel DEX order: $(sprint(showerror, e))", 500, error_code=Utils.ERROR_CODE_SERVER_ERROR)
    end
end

end # module DexHandlers
