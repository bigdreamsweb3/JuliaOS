#!/bin/bash

# update_entry_points.sh
#
# This script updates the entry point files to reflect the new module names.
#
# Usage:
#   ./update_entry_points.sh [--dry-run]
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
            echo "Usage: ./update_entry_points.sh [--dry-run]"
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

# Function to update a file
update_file() {
    local file="$1"
    local old_text="$2"
    local new_text="$3"
    
    if [ -f "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "Would update $file: $old_text -> $new_text"
        else
            echo "Updating $file: $old_text -> $new_text"
            sed -i '' "s|$old_text|$new_text|g" "$file"
        fi
    else
        echo "File does not exist, skipping: $file"
    fi
}

echo "Updating entry point files..."

# Update JuliaOS.jl
echo "Updating JuliaOS.jl..."
update_file "$SRC_DIR/JuliaOS.jl" "export API, Storage, Swarms, SwarmBase, Types, CommandHandler, Agents" "export API, Storage, Swarms, SwarmBase, Types, CommandHandler, Agents, DEX, Bridge"

# Update JuliaOSFramework.jl
echo "Updating JuliaOSFramework.jl..."
update_file "$SRC_DIR/framework/JuliaOSFramework.jl" "export initialize, Storage, Swarms, SwarmBase, Agents, Blockchain, Wallet, Bridge, DEX" "export initialize, Storage, Swarms, SwarmBase, Agents, Blockchain, Wallet, Bridge, DEX, BridgeInterface, BridgeRegistry, DEXBaseTypes, DEXInterface"

# Update JuliaOSCLI.jl
echo "Updating JuliaOSCLI.jl..."
update_file "$SRC_DIR/cli/JuliaOSCLI.jl" "export initialize, run_command, get_command_help, list_commands, CommandHandler" "export initialize, run_command, get_command_help, list_commands, CommandHandler, CommandHandlerRegistry"

# Update imports in JuliaOSFramework.jl
echo "Updating imports in JuliaOSFramework.jl..."
update_file "$SRC_DIR/framework/JuliaOSFramework.jl" "using .Bridge" "using .Bridge, .BridgeInterface, .BridgeRegistry"
update_file "$SRC_DIR/framework/JuliaOSFramework.jl" "using .DEX" "using .DEX, .DEXBaseTypes, .DEXInterface"

# Update imports in JuliaOSCLI.jl
echo "Updating imports in JuliaOSCLI.jl..."
update_file "$SRC_DIR/cli/JuliaOSCLI.jl" "using .CommandHandler" "using .CommandHandler, .CommandHandlerRegistry"

echo "Entry point files updated!"
echo "Please review the changes and make any necessary adjustments."
