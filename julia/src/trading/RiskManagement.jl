"""
RiskManagement.jl - Risk management tools for trading strategies in JuliaOS.
"""
module RiskManagement

export RiskParameters, PositionSizer, StopLossManager, RiskManager
export calculate_position_size, set_stop_loss, set_take_profit, check_risk_limits
export calculate_value_at_risk, calculate_expected_shortfall, calculate_kelly_criterion

using Statistics, Distributions, Logging

"""
    RiskParameters

Parameters defining risk tolerance and rules for a trading strategy or portfolio.
"""
struct RiskParameters
    max_drawdown_percent::Float64    # Maximum acceptable portfolio drawdown (e.g., 20.0 for 20%)
    max_risk_per_trade_percent::Float64 # Maximum percentage of capital to risk on a single trade (e.g., 2.0 for 2%)
    max_position_size_percent::Float64 # Maximum percentage of capital for a single position
    # Add other parameters like VaR limits, leverage constraints, etc.

    function RiskParameters(; 
        max_drawdown_percent=20.0, 
        max_risk_per_trade_percent=2.0,
        max_position_size_percent=10.0
    )
        new(max_drawdown_percent, max_risk_per_trade_percent, max_position_size_percent)
    end
end

"""
    PositionSizer

Manages calculating appropriate position sizes based on risk parameters and market conditions.
"""
mutable struct PositionSizer
    risk_params::RiskParameters
    account_balance::Float64

    function PositionSizer(risk_params::RiskParameters, account_balance::Float64)
        new(risk_params, account_balance)
    end
end

"""
    calculate_position_size(sizer::PositionSizer, entry_price::Float64, stop_loss_price::Float64; volatility::Union{Float64,Nothing}=nothing)::Float64

Calculates the position size in units of the asset.
"""
function calculate_position_size(sizer::PositionSizer, entry_price::Float64, stop_loss_price::Float64; volatility::Union{Float64,Nothing}=nothing)::Float64
    if sizer.account_balance <= 0 || entry_price <= 0 || stop_loss_price <= 0
        @warn "Invalid inputs for position sizing (balance, entry, or stop-loss is non-positive)."
        return 0.0
    end
    
    risk_per_share = abs(entry_price - stop_loss_price)
    if risk_per_share == 0
        @warn "Stop-loss price cannot be the same as entry price for position sizing."
        return 0.0 # Avoid division by zero
    end

    # Max capital to risk on this trade
    capital_at_risk = sizer.account_balance * (sizer.risk_params.max_risk_per_trade_percent / 100.0)
    
    # Number of shares/units based on risk per trade
    num_shares_by_risk = capital_at_risk / risk_per_share
    
    # Max capital for this position
    max_capital_for_position = sizer.account_balance * (sizer.risk_params.max_position_size_percent / 100.0)
    num_shares_by_position_limit = max_capital_for_position / entry_price

    # Use the more conservative of the two
    position_size_units = min(num_shares_by_risk, num_shares_by_position_limit)
    
    @info "Calculated position size: $position_size_units units. Capital at risk: \$$capital_at_risk. Max position capital: \$$max_capital_for_position."
    return position_size_units
end

"""
    StopLossManager

Manages stop-loss and take-profit levels for open positions.
"""
mutable struct StopLossManager
    # Could store active stop-loss/take-profit orders or levels here
    active_stops::Dict{String, Dict{String, Float64}} # e.g. position_id => {"stop_loss"=>price, "take_profit"=>price}

    function StopLossManager()
        new(Dict{String, Dict{String, Float64}}())
    end
end

function set_stop_loss(manager::StopLossManager, position_id::String, stop_price::Float64)
    if !haskey(manager.active_stops, position_id)
        manager.active_stops[position_id] = Dict{String, Float64}()
    end
    manager.active_stops[position_id]["stop_loss"] = stop_price
    @info "Stop-loss for position $position_id set to $stop_price."
end

function set_take_profit(manager::StopLossManager, position_id::String, profit_price::Float64)
     if !haskey(manager.active_stops, position_id)
        manager.active_stops[position_id] = Dict{String, Float64}()
    end
    manager.active_stops[position_id]["take_profit"] = profit_price
    @info "Take-profit for position $position_id set to $profit_price."
end


"""
    RiskManager

Overall risk management component for a trading agent or system.
"""
mutable struct RiskManager
    params::RiskParameters
    position_sizer::PositionSizer
    stop_loss_manager::StopLossManager
    current_portfolio_value::Float64
    initial_portfolio_value::Float64 # To calculate drawdown

    function RiskManager(params::RiskParameters, initial_portfolio_value::Float64)
        sizer = PositionSizer(params, initial_portfolio_value)
        sl_manager = StopLossManager()
        new(params, sizer, sl_manager, initial_portfolio_value, initial_portfolio_value)
    end
end

"""
    check_risk_limits(manager::RiskManager, current_price_or_value::Float64)::Bool

Checks if current portfolio status violates any risk limits (e.g., max drawdown).
This is a simplified check. Real drawdown tracking is more complex.
"""
function check_risk_limits(manager::RiskManager, current_portfolio_value::Float64)::Bool
    manager.current_portfolio_value = current_portfolio_value # Update current value
    
    # Check max drawdown
    current_drawdown_percent = ((manager.initial_portfolio_value - manager.current_portfolio_value) / manager.initial_portfolio_value) * 100
    if current_drawdown_percent > manager.params.max_drawdown_percent
        @warn "Max drawdown limit exceeded! Current: $(current_drawdown_percent)%, Limit: $(manager.params.max_drawdown_percent)%."
        return false # Risk limit violated
    end
    
    # TODO: Add other checks (e.g., overall portfolio VaR, concentration limits)
    return true # All checks passed
end


# --- Advanced Risk Metrics (Placeholders/Simplified) ---

"""
    calculate_value_at_risk(returns::Vector{Float64}, confidence_level::Float64=0.95)::Float64

Calculates Value at Risk (VaR) using historical simulation (simplified).
`returns` are typically daily percentage returns (e.g., 0.01 for 1%).
"""
function calculate_value_at_risk(returns::Vector{Float64}, confidence_level::Float64=0.95)::Float64
    isempty(returns) && return 0.0
    sorted_returns = sort(returns)
    index = ceil(Int, (1.0 - confidence_level) * length(sorted_returns))
    index = max(1, min(index, length(sorted_returns))) # Ensure index is valid
    var_value = sorted_returns[index] 
    return abs(var_value) # VaR is typically reported as a positive loss value
end

"""
    calculate_expected_shortfall(returns::Vector{Float64}, confidence_level::Float64=0.95)::Float64

Calculates Conditional Value at Risk (CVaR) or Expected Shortfall.
"""
function calculate_expected_shortfall(returns::Vector{Float64}, confidence_level::Float64=0.95)::Float64
    isempty(returns) && return 0.0
    var_threshold = -calculate_value_at_risk(returns, confidence_level) # VaR as a negative return
    tail_losses = filter(r -> r <= var_threshold, returns)
    return isempty(tail_losses) ? 0.0 : abs(mean(tail_losses))
end

"""
    calculate_kelly_criterion(win_probability::Float64, avg_win_loss_ratio::Float64)::Float64

Calculates the Kelly Criterion for bet sizing.
`avg_win_loss_ratio` = (average gain from a win) / (average loss from a loss), both positive.
"""
function calculate_kelly_criterion(win_probability::Float64, avg_win_loss_ratio::Float64)::Float64
    if !(0 <= win_probability <= 1) || avg_win_loss_ratio <= 0
        @warn "Invalid inputs for Kelly Criterion."
        return 0.0
    end
    # Kelly fraction = W - ( (1-W) / R )
    # W = win_probability
    # R = avg_win_loss_ratio
    kelly_fraction = win_probability - ((1 - win_probability) / avg_win_loss_ratio)
    return max(0.0, kelly_fraction) # Bet size cannot be negative
end

end # module RiskManagement
