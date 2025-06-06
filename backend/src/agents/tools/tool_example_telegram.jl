using DotEnv
DotEnv.load!()

using ...Resources: Gemini
using ..CommonTypes: ToolSpecification, ToolMetadata, ToolConfig
using HTTP
using JSON

GEMINI_API_KEY = ENV["GEMINI_API_KEY"]
GEMINI_MODEL = "models/gemini-1.5-pro"

Base.@kwdef struct ToolDetectSwearConfig <: ToolConfig
    api_key::String = GEMINI_API_KEY
    model_name::String = GEMINI_MODEL
    temperature::Float64 = 0.0
    max_output_tokens::Int = 64
end

function tool_detect_swearing(
    cfg::ToolDetectSwearConfig,
    text::String
)::Bool
    prompt = """
    You are a profanity detector. Answer with YES if the following user message contains profanity or hate speech; otherwise respond with NO.

    Message:
    $(text)
    """

    gemini_cfg = Gemini.GeminiConfig(
        api_key = cfg.api_key,
        model_name = cfg.model_name,
        temperature = cfg.temperature,
        max_output_tokens = cfg.max_output_tokens
    )

    raw = Gemini.gemini_util(
        gemini_cfg,
        prompt
    )

    normalized = lowercase(strip(raw))
    return startswith(normalized, "yes")
end

const TOOL_DETECT_SWEAR_METADATA = ToolMetadata(
    "detect_swearing",
    "Uses Gemini to classify whether a message contains profanity."
)

const TOOL_DETECT_SWEAR_SPECIFICATION = ToolSpecification(
    tool_detect_swearing,
    ToolDetectSwearConfig,
    TOOL_DETECT_SWEAR_METADATA
)


Base.@kwdef struct ToolBanUserConfig <: ToolConfig
    api_token::String
end

function tool_ban_user(
    cfg::ToolBanUserConfig,
    data::NamedTuple{(:chat_id,:user_id),Tuple{Int,Int}}
)::Bool
    chat_id, user_id = data.chat_id, data.user_id
    url = "https://api.telegram.org/bot$(cfg.api_token)/banChatMember"
    body = JSON.json(Dict("chat_id" => chat_id, "user_id" => user_id))

    resp = HTTP.request(
        "POST",
        url;
        headers = ["Content-Type" => "application/json"],
        body = body
    )

    if resp.status != 200
        @warn "Failed to ban user" user_id=user_id chat_id=chat_id status=resp.status
        return false
    end

    msg_url = "https://api.telegram.org/bot$(cfg.api_token)/sendMessage"
    text = "User with ID $user_id has been banned."
    msg_body = JSON.json(Dict("chat_id" => chat_id, "text" => text))

    msg_resp = HTTP.request(
        "POST",
        msg_url;
        headers = ["Content-Type" => "application/json"],
        body = msg_body
    )

    if msg_resp.status != 200
        @warn "Failed to send ban confirmation message" chat_id=chat_id status=msg_resp.status
        return false
    end

    return true
end

const TOOL_BAN_USER_METADATA = ToolMetadata(
    "ban_user",
    "Calls Telegram’s banChatMember API to ban a user from a chat."
)

const TOOL_BAN_USER_SPECIFICATION = ToolSpecification(
    tool_ban_user,
    ToolBanUserConfig,
    TOOL_BAN_USER_METADATA
)
