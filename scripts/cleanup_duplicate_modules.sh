#!/bin/bash

# cleanup_duplicate_modules.sh
#
# This script cleans up duplicate modules in the JuliaOS codebase.
#
# Usage:
#   ./cleanup_duplicate_modules.sh [--dry-run]
#
# Options:
#   --dry-run    Show what would be done without actually doing it

# Parse command line arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            # Unknown option
            echo "Unknown option: $arg"
            echo "Usage: ./cleanup_duplicate_modules.sh [--dry-run]"
            exit 1
            ;;
    esac
done

# Set up paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
JULIA_DIR="$PROJECT_ROOT/julia"
SRC_DIR="$JULIA_DIR/src"

# Function to execute or print a command
execute() {
    if [ "$DRY_RUN" = true ]; then
        echo "Would execute: $*"
    else
        echo "Executing: $*"
        "$@"
    fi
}

# Function to rename a module in a file
rename_module() {
    local file="$1"
    local old_name="$2"
    local new_name="$3"
    
    if [ -f "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "Would rename module $old_name to $new_name in $file"
        else
            echo "Renaming module $old_name to $new_name in $file"
            sed -i '' "s/module $old_name/module $new_name/" "$file"
            
            # Also update any references to the module in the same file
            sed -i '' "s/using .$old_name/using .$new_name/" "$file"
            sed -i '' "s/import .$old_name/import .$new_name/" "$file"
            sed -i '' "s/export $old_name/export $new_name/" "$file"
            sed -i '' "s/$old_name\./$new_name\./" "$file"
            sed -i '' "s/end # module $old_name/end # module $new_name/" "$file"
        fi
    else
        echo "File does not exist, skipping: $file"
    fi
}

# Function to update references to a renamed module in all files
update_module_references() {
    local dir="$1"
    local old_name="$2"
    local new_name="$3"
    
    if [ -d "$dir" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "Would update references to module $old_name to $new_name in $dir"
        else
            echo "Updating references to module $old_name to $new_name in $dir"
            find "$dir" -type f -name "*.jl" -exec sed -i '' "s/using .$old_name/using .$new_name/g" {} \;
            find "$dir" -type f -name "*.jl" -exec sed -i '' "s/import .$old_name/import .$new_name/g" {} \;
            find "$dir" -type f -name "*.jl" -exec sed -i '' "s/export $old_name/export $new_name/g" {} \;
            find "$dir" -type f -name "*.jl" -exec sed -i '' "s/$old_name\./$new_name\./g" {} \;
        fi
    else
        echo "Directory does not exist, skipping: $dir"
    fi
}

echo "Cleaning up duplicate modules..."

# 1. Bridge module duplicates
echo "Cleaning up Bridge module duplicates..."
# Rename bridge_interface.jl module to BridgeInterface
rename_module "$SRC_DIR/framework/bridges/bridge_interface.jl" "Bridge" "BridgeInterface"
# Rename bridges.jl module to BridgeRegistry
rename_module "$SRC_DIR/framework/bridges/bridges.jl" "Bridge" "BridgeRegistry"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "Bridge" "Bridge"

# 2. CommandHandler module duplicates
echo "Cleaning up CommandHandler module duplicates..."
# Rename CommandHandlers.jl module to CommandHandlerRegistry
rename_module "$SRC_DIR/cli/commands/handlers/CommandHandlers.jl" "CommandHandler" "CommandHandlerRegistry"
# Rename command_handler.jl module to LegacyCommandHandler
rename_module "$SRC_DIR/command_handler.jl" "CommandHandler" "LegacyCommandHandler"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "CommandHandler" "CommandHandler"

# 3. DEX module duplicates
echo "Cleaning up DEX module duplicates..."
# Rename DEXBase.jl module to DEXBaseTypes
rename_module "$SRC_DIR/framework/dex/DEXBase.jl" "DEX" "DEXBaseTypes"
# Rename DEXAggregator.jl module to DEXAggregatorModule
rename_module "$SRC_DIR/framework/dex/DEXAggregator.jl" "DEX" "DEXAggregatorModule"
# Rename DEXIntegration.jl module to DEXIntegrationModule
rename_module "$SRC_DIR/framework/dex/DEXIntegration.jl" "DEX" "DEXIntegrationModule"
# Rename dex_interface.jl module to DEXInterface
rename_module "$SRC_DIR/framework/dex/dex_interface.jl" "DEX" "DEXInterface"
# Rename DEXCommands.jl module to DEXCommandsModule
rename_module "$SRC_DIR/framework/dex/DEXCommands.jl" "DEX" "DEXCommandsModule"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "DEX" "DEX"

# 4. Handlers module duplicates
echo "Cleaning up Handlers module duplicates..."
# Rename core/api/Handlers.jl module to APIHandlers
rename_module "$SRC_DIR/core/api/Handlers.jl" "Handlers" "APIHandlers"
# Rename cli/commands/handlers/Handlers.jl module to CLIHandlers
rename_module "$SRC_DIR/cli/commands/handlers/Handlers.jl" "Handlers" "CLIHandlers"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "Handlers" "APIHandlers"
update_module_references "$SRC_DIR" "Handlers" "CLIHandlers"

# 5. Metrics module duplicates
echo "Cleaning up Metrics module duplicates..."
# Rename agents/Agents.jl Metrics module to AgentMetrics
rename_module "$SRC_DIR/framework/agents/Agents.jl" "Metrics" "AgentMetrics"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "Metrics" "Metrics"

# 6. RiskManagement module duplicates
echo "Cleaning up RiskManagement module duplicates..."
# Rename core/utils/RiskManagement.jl module to CoreRiskManagement
rename_module "$SRC_DIR/core/utils/RiskManagement.jl" "RiskManagement" "CoreRiskManagement"
# Rename trading/RiskManagement.jl module to TradingRiskManagement
rename_module "$SRC_DIR/framework/trading/RiskManagement.jl" "RiskManagement" "TradingRiskManagement"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "RiskManagement" "CoreRiskManagement"
update_module_references "$SRC_DIR" "RiskManagement" "TradingRiskManagement"

# 7. TestUtils module duplicates
echo "Cleaning up TestUtils module duplicates..."
# Rename test_utils.jl module to TestUtilsModule
rename_module "$SRC_DIR/core/utils/test_utils.jl" "TestUtils" "TestUtilsModule"
# Update references to the renamed modules
update_module_references "$SRC_DIR" "TestUtils" "TestUtils"

echo "Duplicate modules cleanup complete!"
echo "Please review the changes and make any necessary adjustments."
