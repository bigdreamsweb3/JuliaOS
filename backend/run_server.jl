using Pkg
Pkg.activate(".")

using JuliaOSBackend.JuliaOSV1Server

function main()
    port = 8052
    JuliaOSV1Server.run_server(port)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end