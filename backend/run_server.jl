using Pkg
Pkg.activate(".")

using JuliaOSBackend.JuliaOSV1Server

function main()
    host = get(ENV, "HOST", "127.0.0.1")
    port = parse(Int, get(ENV, "PORT", "8052"))
    JuliaOSV1Server.run_server(host, port)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end