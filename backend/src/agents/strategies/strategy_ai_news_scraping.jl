using ..CommonTypes: StrategyConfig, AgentContext, StrategySpecification
using Gumbo, Cascadia, HTTP


Base.@kwdef struct StrategyAINewsAgentConfig <: StrategyConfig
    news_portal_url::String = "https://techcrunch.com/category/artificial-intelligence/"
    css_selector::String = "a[href]"
    url_pattern::Union{Nothing, String} = "/\\d{4}/\\d{2}/\\d{2}/"
end

function extract_latest_article_url(html::String, css_selector::String, url_pattern::Union{Nothing, String})
    parsed = parsehtml(html)
    nodes = eachmatch(Selector(css_selector), parsed.root)

    for node in nodes
        href = Gumbo.getattr(node, "href")
        if href === nothing || !startswith(href, "http")
            continue
        end

        if isnothing(url_pattern) || occursin(Regex(url_pattern), href)
            return href
        end
    end

    return nothing
end

function strategy_ai_news_scraping(cfg::StrategyAINewsAgentConfig, ctx::AgentContext, input::Dict{String,Any})
    scrape_index = findfirst(t -> t.metadata.name == "scrape_article_text", ctx.tools)
    summarize_index = findfirst(t -> t.metadata.name == "summarize_for_post", ctx.tools)

    if scrape_index === nothing || summarize_index === nothing
        push!(ctx.logs, "Missing required tool(s)")
        return ctx
    end

    portal_html = ""
    try
        response = HTTP.get(cfg.news_portal_url)
        portal_html = String(response.body)
    catch e
        push!(ctx.logs, "Failed to fetch portal HTML: $(cfg.news_portal_url) — $(sprint(showerror, e))")
        return ctx
    end

    article_url = extract_latest_article_url(portal_html, cfg.css_selector, cfg.url_pattern)

    if article_url === nothing
        push!(ctx.logs, "No matching article URL found on portal")
        return ctx
    end

    article_result = ctx.tools[scrape_index].execute(ctx.tools[scrape_index].config, Dict("url" => article_url))
    if !get(article_result, "success", false)
        push!(ctx.logs, "Failed to scrape article: $article_url")
        return ctx
    end

    article_text = article_result["text"]

    summarize_result = ctx.tools[summarize_index].execute(ctx.tools[summarize_index].config, Dict(
        "text" => article_text,
        "url" => article_url
    ))

    if !get(summarize_result, "success", false)
        push!(ctx.logs, "Failed to summarize article: $article_url")
        return ctx
    end

    tweet = summarize_result["post_text"]
    @info "Generated tweet: $tweet"

    return ctx
end

const STRATEGY_AI_NEWS_SCRAPING_SPECIFICATION = StrategySpecification(
    strategy_ai_news_scraping,
    nothing,
    StrategyAINewsAgentConfig,
)
