# JuliaOS Python Modules

The `juliaos` Python module is intended to provide a way of interacting with a JuliaOS backend, enabling users to control their agents through a Python script.

## Development

Requires Python 3.11+.

First, optionally, set up and activate your venv here in the `python/` directory.

You can then install the module using

```
pip install -e .
```

after which you should be able to use the module inside `scripts/` simply as `import juliaos`. Any changes made to the module will be reflected automatically.

If you are working in an environment which does not work well with editable installs, you can also try installing one of the earlier versions from TestPyPI:

```
pip install --extra-index-url https://test.pypi.org/simple/ juliaos==0.1.1
```

Note that this will only install that specific version, any changes to the module made locally will **not** be reflected.

### Example Scripts

You can find several examples of how to use the module in the scripts inside `scripts/`. Note that for some of them (the ones interacting with Telegram and X), you will need to set up an `.env` file with the necessary tokens &ndash; use `.env.example` as a guidline for which environmental variables are used.

### Notes on dependencies

Most of the dependencies specified in `pyproject.toml` are given by the generated client code, and are marked as such. The one exception is `dotenv`, which is not needed at all for the `juliaos` package itself, but is a requirement for some of the example scripts in `scripts/`.

If you want to remove this dependency from the package, you will need to install it in some other way before running these scripts, e.g. by

```
pip install dotenv
```

### Client generation

The client code inside `python/src/_juliaos_client_api` is automatically generated from the OpenAPI specification found at `backend/src/api/spec/api-spec.yaml`. To regenerate this code after the specification has been updated, use the `generate-python-client.sh` script in the root of the repository. Note that for this script to work, you will need to install java 11+ and download the OpenAPI Generator CLI .jar file &ndash; see the script for more details. Also note that only some of the generated files are needed and copied to this subdirectory &ndash; in case you want to inspect the rest of the generated files after running the script, such as the generated README, you will be able to find them in a directory named `temp-generated` in the root of the repository.