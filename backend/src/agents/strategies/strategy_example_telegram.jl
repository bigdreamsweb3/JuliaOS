using ..CommonTypes: StrategyConfig, AgentContext, StrategySpecifications
using HTTP
using JSON


Base.@kwdef struct StrategyTelegramModeratorConfig <: StrategyConfig
end

function strategy_telegram_moderator(
        cfg::StrategyTelegramModeratorConfig,
        ctx::AgentContext,
        input::Dict{String,Any}
    )
    if !haskey(input, "message") || !(input["message"] isa Dict{String,Any})
        push!(ctx.logs, "ERROR: payload missing “message” or it’s not a Dict")
        return ctx
    end

    msg = input["message"]::Dict{String,Any}
    if !(haskey(msg, "chat") && haskey(msg["chat"], "id") &&
         haskey(msg["from"], "id") && haskey(msg, "text"))
        push!(ctx.logs, "ERROR: Message JSON missing chat/id/from/text.")
        return ctx
    end

    chat_id = msg["chat"]["id"]
    user_id = msg["from"]["id"]
    text    = msg["text"]

    detect_index = findfirst(tool -> tool.metadata.name == "detect_swearing", ctx.tools)
    if detect_index === nothing
        push!(ctx.logs, "ERROR: detect_swearing tool not found.")
        return ctx
    end
    detect_tool = ctx.tools[detect_index]

    is_swear = false
    try
        is_swear = detect_tool.execute(
            detect_tool.config,
            text
        )
    catch e
        push!(ctx.logs, "ERROR: Profanity detection failed: $e")
        return ctx
    end

    if is_swear
        ban_index = findfirst(tool -> tool.metadata.name == "ban_user", ctx.tools)
        if ban_index === nothing
            push!(ctx.logs, "ERROR: ban_user tool not found.")
            return ctx
        end
        ban_tool = ctx.tools[ban_index]

        success = false
        try
            success = ban_tool.execute(
                ban_tool.config,
                (chat_id = chat_id, user_id = user_id)
            )
        catch e
            push!(ctx.logs, "ERROR: Failed to call banChatMember: $e")
            return ctx
        end

        if success
            push!(ctx.logs, "🔨 Banned user $user_id from chat $chat_id for profanity: $(text)")
        else
            push!(ctx.logs, "❗ Failed to ban user $user_id from chat $chat_id.")
        end

    else
        push!(ctx.logs, "✅ No profanity detected from $user_id: $(text)")
    end

    return ctx
end

const STRATEGY_TELEGRAM_MODERATOR_SPECIFICATION = StrategySpecification(
    strategy_telegram_moderator,
    StrategyTelegramModeratorConfig
)
