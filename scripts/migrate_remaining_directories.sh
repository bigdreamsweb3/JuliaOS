#!/bin/bash

# migrate_remaining_directories.sh
#
# This script migrates the remaining directories to the new structure.
#
# Usage:
#   ./migrate_remaining_directories.sh [--dry-run]
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
            echo "Usage: ./migrate_remaining_directories.sh [--dry-run]"
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

# Function to copy a directory if it exists
copy_if_exists() {
    if [ -d "$1" ]; then
        execute cp -r "$1" "$2"
    else
        echo "Directory does not exist, skipping: $1"
    fi
}

# Function to remove a directory if it exists
remove_if_exists() {
    if [ -d "$1" ]; then
        execute rm -rf "$1"
    else
        echo "Directory does not exist, skipping: $1"
    fi
}

echo "Migrating remaining directories..."

# Create necessary directories
echo "Creating necessary directories..."
execute mkdir -p "$SRC_DIR/framework/price"
execute mkdir -p "$SRC_DIR/framework/trading"
execute mkdir -p "$SRC_DIR/framework/visualization"
execute mkdir -p "$SRC_DIR/core/api"

# Move price directory to framework
echo "Moving price directory to framework..."
copy_if_exists "$SRC_DIR/price" "$SRC_DIR/framework/"

# Move trading directory to framework
echo "Moving trading directory to framework..."
copy_if_exists "$SRC_DIR/trading" "$SRC_DIR/framework/"

# Move visualization directory to framework
echo "Moving visualization directory to framework..."
copy_if_exists "$SRC_DIR/visualization" "$SRC_DIR/framework/"

# Move API directory to core
echo "Moving API directory to core..."
copy_if_exists "$SRC_DIR/api" "$SRC_DIR/core/"

# Update the JuliaOSFramework.jl file to include the new modules
if [ "$DRY_RUN" = false ]; then
    echo "Updating JuliaOSFramework.jl..."
    
    # Find the line before "end # module" in JuliaOSFramework.jl
    LINE_NUM=$(grep -n "end # module" "$SRC_DIR/framework/JuliaOSFramework.jl" | cut -d: -f1)
    INSERT_LINE=$((LINE_NUM - 1))
    
    # Insert the new includes
    sed -i '' "${INSERT_LINE}r /dev/stdin" "$SRC_DIR/framework/JuliaOSFramework.jl" << EOF

# Price feed implementations
include("price/price_feed.jl")

# Trading implementations
include("trading/trading_strategy.jl")

# Visualization implementations
include("visualization/visualization.jl")
EOF
else
    echo "Would update JuliaOSFramework.jl to include the new modules"
fi

# Update the JuliaOSCLI.jl file to use the core/api
if [ "$DRY_RUN" = false ]; then
    echo "Updating JuliaOSCLI.jl..."
    
    # Replace "../api/" with "../core/api/" in JuliaOSCLI.jl
    sed -i '' 's|"../api/|"../core/api/|g' "$SRC_DIR/cli/JuliaOSCLI.jl"
else
    echo "Would update JuliaOSCLI.jl to use core/api"
fi

# Update the JuliaOS.jl file to use the core/api
if [ "$DRY_RUN" = false ]; then
    echo "Updating JuliaOS.jl..."
    
    # No need to update JuliaOS.jl as it now just includes the framework and CLI modules
else
    echo "No need to update JuliaOS.jl"
fi

echo "Migration of remaining directories complete!"
echo "Please review the changes and make any necessary adjustments."

# Ask if the user wants to remove the original directories
if [ "$DRY_RUN" = false ]; then
    echo ""
    echo "Do you want to remove the original directories? (y/n)"
    read -r REMOVE_ORIGINAL
    
    if [ "$REMOVE_ORIGINAL" = "y" ]; then
        echo "Removing original directories..."
        remove_if_exists "$SRC_DIR/price"
        remove_if_exists "$SRC_DIR/trading"
        remove_if_exists "$SRC_DIR/visualization"
        remove_if_exists "$SRC_DIR/api"
        echo "Original directories removed."
    else
        echo "Original directories not removed."
    fi
fi
