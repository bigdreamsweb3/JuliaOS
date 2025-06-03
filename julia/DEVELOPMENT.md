# JuliaOS Development Documentation

## Project Overview

JuliaOS is an intelligent trading system developed in Julia, integrating multiple functional modules including trading, risk management, data storage, and intelligent agents.

## Project Structure

```
JuliaOS/
├── src/                    # Source code directory
│   ├── agents/            # Intelligent agent module
│   ├── trading/           # Trading module
│   ├── risk/             # Risk management module
│   └── ...               # Other modules
├── test/                  # Test directory
│   ├── agents/           # Agent module tests
│   ├── trading/          # Trading module tests
│   └── ...               # Other module tests
└── examples/             # Example code directory
```

## Development Environment Setup

1. Install Julia (recommended version 1.8 or higher)
2. Clone the project and enter the project directory
3. Activate the project environment and install dependencies:
```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Testing Framework

### Running Tests

The project provides npm scripts for running tests:

1. Run all tests:
```bash
npm run test
# or
npm run test:all
```

2. Run specific test file:
```bash
npm run test:file -- test/agents/agents_test.jl
```

3. Run multiple test files:
```bash
# Run multiple test files one by one
npm run test:file -- test/agents/agents_test.jl
npm run test:file -- test/agents/agent_core_test.jl
```

Note: When using `test:file`, make sure to add `--` before the file path to properly pass arguments to the script.

### Test File Organization

Test files are organized by module in the `test` directory, with each module having its own test directory:

- `test/agents/`: Intelligent agent module tests
- `test/trading/`: Trading module tests
- `test/risk/`: Risk management module tests
- etc...

Each test directory contains:
- `runtests.jl`: Module test entry file
- `*_test.jl`: Specific test files

### Writing Tests

Tests use Julia's standard testing framework `Test`. Example:

```julia
# test/agents/example_test.jl
using Test
using JuliaOS.Agents

@testset "Agent Tests" begin
    # Test cases
    @test true
end
```

## Example Code

### Creating and Using Intelligent Agents

```julia
# examples/create_agent.jl
using JuliaOS.Agents
using JuliaOS.AgentCore

# Create agent configuration
config = AgentConfig(
    "trading_agent",
    TRADING,
    abilities=["market_analysis", "trade_execution"],
    parameters=Dict("risk_limit" => 0.1)
)

# Create agent
agent = createAgent(config)

# Start agent
startAgent(agent.id)

# Execute task
task_id = executeAgentTask(agent.id, "market_analysis", "BTC/USD")

# Get task result
result = getTaskResult(agent.id, task_id)
```

Run the example:
```bash
julia --project=. examples/create_agent.jl
```

### Using Agent Memory

```julia
# examples/agent_memory.jl
using JuliaOS.Agents

# Set memory
setAgentMemory(agent.id, "last_price", 50000.0)

# Get memory
price = getAgentMemory(agent.id, "last_price")

# Clear memory
clearAgentMemory(agent.id)
```

Run the example:
```bash
julia --project=. examples/agent_memory.jl
```

## Development Guidelines

### Code Style

- Use 4-space indentation
- Use lowercase letters and underscores for function names
- Use camelCase for type names
- Add appropriate comments and docstrings

### Commit Convention

Commit message format:
```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation
- style: Formatting
- refactor: Code refactoring
- test: Adding tests
- chore: Build process or auxiliary tool changes

### Branch Management

- `main`: Main branch, keep stable
- `develop`: Development branch
- `feature/*`: Feature branches
- `bugfix/*`: Bug fix branches

## Common Issues

### Testing Related

1. How to debug test failures?
   ```bash
   # Run tests with detailed output
   npm run test -- --verbose
   
   # Run specific test with debug output
   npm run test:file test/agents/agents_test.jl -- --verbose
   ```

2. How to add new tests?
   ```bash
   # Create new test file
   touch test/agents/new_feature_test.jl
   
   # Add test file to runtests.jl
   echo 'include("agents/new_feature_test.jl")' >> test/agents/runtests.jl
   ```

### Development Related

1. How to add new agent types?
   ```bash
   # Edit AgentCore.jl
   vim src/agents/AgentCore.jl
   
   # Run tests for the changes
   npm run test:file test/agents/agent_core_test.jl
   ```

2. How to extend agent capabilities?
   ```bash
   # Create new skill file
   touch src/agents/skills/new_skill.jl
   
   # Register skill in your code
   julia --project=. -e 'using JuliaOS.Agents; register_skill("new_skill", your_function)'
   ```

## Contributing Guide

1. Fork the project
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

[Add license information]