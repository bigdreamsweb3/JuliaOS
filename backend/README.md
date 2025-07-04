# JuliaOS Backend

The core agent framework of JuliaOS with an accompanying server and database.

## Prerequisites

One option of running the backend is through [Docker](https://www.docker.com/), in which case you don't necessarily need Julia, though this is not recommended for development.

To run the backend without Docker, you will need to install Julia (version >= 1.11.4) &ndash; see [the official installation instructions](https://julialang.org/install/). The method currently recommended is to install [juliaup](https://github.com/JuliaLang/juliaup), which you can then use to install and manage various versions of Julia.

The backend will also need a postgres database, which you can either set up yourself or run with Docker using the instructions in the following section.

## Running

Before running the backend, prepare an `.env` file. You can start this by copying the example env file:

```
cp .env.example .env
```

and afterwards adjust as needed. The various API keys are only needed if you intend to use the tools and strategies that use them.

To run the backend and the database using docker, simply run the following:

```
docker compose up
```

To run just the database, which can also be used alongside the backend running outside of docker, run the following:

```
docker compose up julia-db
```

You can also set up your own postgres database outside of docker, just make sure its configuration is reflected in the `.env` file.

To install all the required Julia packages, run the following:

```
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

Afterwards, if the database is running and the `.env` file is set up correctly, you should be able to run the backend by executing:

```
julia --project=. run_server.jl
```

## Server generation

The part of the server code inside `backend/src/api/server/` is automatically generated from the OpenAPI specification at `backend/src/api/spec/api-spec.yaml`. To regenerate this code after the specification has been updated, use the `generate-server.sh` script in the root of the repository. Note that for this script to work, you will need to install java 11+ and download the OpenAPI Generator CLI .jar file &ndash; see the script for more details.