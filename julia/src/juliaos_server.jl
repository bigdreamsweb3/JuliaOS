module JuliaOSV1Server

using HTTP

include("api/server/src/JuliaOSServer.jl")

using .JuliaOSServer

const server = Ref{Any}(nothing)
const agents = Vector{Agent}()

function create_agent(req::HTTP.Request, agent::Agent)
    @info "Triggered endpoint: POST /agents"
    @info "NYI, not actually creating agent $(agent.id)..."
    return nothing
end

function list_agents(req::HTTP.Request)
    @info "Triggered endpoint: GET /agents"
    @info "NYI, not actually listing agents..."
    return agents
end

function ping(::HTTP.Request)
    @info "Triggered endpoint: GET /ping"
    return HTTP.Response(200, "")
end

function run_server(port=8052)
    try
        router = HTTP.Router()
        router = JuliaOSServer.register(router, @__MODULE__; path_prefix="/api/v1")
        HTTP.register!(router, "GET", "/ping", ping)
        server[] = HTTP.serve!(router, port)
        wait(server[])
    catch ex
        @error("Server error", exception=(ex, catch_backtrace()))
    end
end

end # module JuliaOSV1Server

JuliaOSV1Server.run_server()