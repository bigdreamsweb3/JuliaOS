using ..CommonTypes: ToolSpecification, ToolMetadata, ToolConfig
using HTTP
using JSON

Base.@kwdef struct GeminiConfig
    api_key::String
    model_name::String
    temperature::Float64 = 0.0
    max_output_tokens::Int = 256
end

"""
    gemini_util(cfg::GeminiConfig, prompt::String) :: String

Sends prompt to Gemini’s API and returns its text completion.
"""
function gemini_util(
    cfg::GeminiConfig,
    prompt::String
)::String
    endpoint_url = "https://generativelanguage.googleapis.com/v1beta/$(cfg.model_name):generateContent?key=$(cfg.api_key)"

    body_dict = Dict(
        "contents" => [
            Dict("parts" => [ Dict("text" => prompt) ])
        ],
        "generationConfig" => Dict(
            "temperature"      => cfg.temperature,
            "maxOutputTokens"  => cfg.max_output_tokens
        )
    )
    request_body = JSON.json(body_dict)

    resp = HTTP.request(
        "POST",
        endpoint_url;
        headers = ["Content-Type" => "application/json"],
        body = request_body
    )

    if resp.status != 200
        error("Gemini generateContent failed with status $(resp.status): $(String(resp.body))")
    end

    resp_json = JSON.parse(String(resp.body))

    if !haskey(resp_json, "candidates") || isempty(resp_json["candidates"])
        error("Gemini response missing 'candidates' or the list is empty.")
    end
    first_candidate = resp_json["candidates"][1]

    if !haskey(first_candidate, "content") ||
       !haskey(first_candidate["content"], "parts") ||
       isempty(first_candidate["content"]["parts"])
        error("Gemini response’s first candidate missing 'content.parts'.")
    end

    generated_text = first_candidate["content"]["parts"][1]["text"]
    return generated_text
end


Base.@kwdef struct ToolDetectSwearConfig <: ToolConfig
    api_key::String
    model_name::String
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

    gemini_cfg = GeminiConfig(
        api_key = cfg.api_key,
        model_name = cfg.model_name,
        temperature = cfg.temperature,
        max_output_tokens = cfg.max_output_tokens
    )

    raw = gemini_util(
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
    return resp.status == 200
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
