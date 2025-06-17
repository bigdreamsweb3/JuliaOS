using DotEnv
DotEnv.load!()

using ...Resources: Gemini
using ..CommonTypes: ToolSpecification, ToolMetadata, ToolConfig


GEMINI_API_KEY = ENV["GEMINI_API_KEY"]
GEMINI_MODEL = "models/gemini-1.5-pro"

Base.@kwdef struct ToolBlogWriterConfig <: ToolConfig
    api_key::String = GEMINI_API_KEY
    model_name::String = GEMINI_MODEL
    temperature::Float64 = 0.7
    max_output_tokens::Int = 1024
end

const ALLOWED_FORMATS = Set(["plain", "markdown", "html"])

function tool_write_blog(cfg::ToolBlogWriterConfig, task::Dict)
    if !haskey(task, "title") || !(task["title"] isa AbstractString)
        return Dict("success" => false, "error" => "Missing or invalid 'topic'")
    elseif haskey(task, "output_format") && lowercase(task["output_format"]) ∉ ALLOWED_FORMATS
        return Dict("success" => false, "error" => "Invalid 'output_format'. Allowed formats: $(join(ALLOWED_FORMATS, ", "))")
    end

    title = task["title"]
    tone = get(task, "tone", "neutral")
    length = get(task, "length", "medium")
    output_format = get(task, "output_format", "plain")

    prompt = """
    Write a blog post on the topic "$title" in a $tone tone.
    The post should be $length length and include an introduction, 2–3 paragraphs in the body, and a conclusion.
    Make it engaging and well-structured.
    Return the output in the following format: $output_format.
    """

    gemini_cfg = Gemini.GeminiConfig(
        api_key = cfg.api_key,
        model_name = cfg.model_name,
        temperature = cfg.temperature,
        max_output_tokens = cfg.max_output_tokens
    )

    try
        answer = Gemini.gemini_util(
            gemini_cfg, 
            prompt
        )
        return Dict("output" => answer, "success" => true)
    catch e
        return Dict("success" => false, "error" => string(e))
    end
end

const TOOL_BLOG_WRITER_METADATA = ToolMetadata(
    "write_blog",
    "Generates a structured blog post based on a given topic and optional settings."
)

const TOOL_BLOG_WRITER_SPECIFICATION = ToolSpecification(
    tool_write_blog,
    ToolBlogWriterConfig,
    TOOL_BLOG_WRITER_METADATA
)
