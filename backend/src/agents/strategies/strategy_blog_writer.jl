using ..CommonTypes: StrategyConfig, AgentContext, StrategySpecification

Base.@kwdef struct StrategyBlogWriterConfig <: StrategyConfig
end

function strategy_blog_writer(
        cfg::StrategyBlogWriterConfig,
        ctx::AgentContext,
        input::Dict{String,Any}
    )
    if !haskey(input, "title")
        push!(ctx.logs, "ERROR: Input must contain 'title'.")
        return ctx
    end

    title = input["title"]
    tone = input["tone"]
    length = input["length"]

    detect_index = findfirst(tool -> tool.metadata.name == "write_blog", ctx.tools)
    if detect_index === nothing
        push!(ctx.logs, "ERROR: write_blog tool not found.")
        return ctx
    end
    blog_writer_tool = ctx.tools[detect_index]
    
    push!(ctx.logs, "Writing blog post with:\ntitle: $title \ntone: $tone \nlength: $length")
    try
        result = blog_writer_tool.execute(blog_writer_tool.config, input)
        push!(ctx.logs, "Blog post '$title' written successfully.")
        push!(ctx.logs, "Blog content: \n$(result["output"])")
    catch e
        push!(ctx.logs, "ERROR: Blog writing failed: $e")
        return ctx
    end    
end

const STRATEGY_BLOG_WRITER_SPECIFICATION = StrategySpecification(
    strategy_blog_writer,
    nothing,
    StrategyBlogWriterConfig
)