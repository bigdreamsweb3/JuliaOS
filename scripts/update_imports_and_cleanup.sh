#!/bin/bash

# update_imports_and_cleanup.sh
#
# This script updates import paths in the migrated files and cleans up duplicate modules.
#
# Usage:
#   ./update_imports_and_cleanup.sh [--dry-run]
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
            echo "Usage: ./update_imports_and_cleanup.sh [--dry-run]"
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

# Function to update import paths in a file
update_imports() {
    local file="$1"
    local old_path="$2"
    local new_path="$3"
    
    if [ -f "$file" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "Would update import paths in $file: $old_path -> $new_path"
        else
            echo "Updating import paths in $file: $old_path -> $new_path"
            sed -i '' "s|$old_path|$new_path|g" "$file"
        fi
    else
        echo "File does not exist, skipping: $file"
    fi
}

# Function to find and update import paths in all Julia files in a directory
find_and_update_imports() {
    local dir="$1"
    local old_path="$2"
    local new_path="$3"
    
    if [ -d "$dir" ]; then
        echo "Finding and updating import paths in $dir..."
        
        if [ "$DRY_RUN" = true ]; then
            echo "Would find all .jl files in $dir and update import paths: $old_path -> $new_path"
        else
            find "$dir" -type f -name "*.jl" -exec sed -i '' "s|$old_path|$new_path|g" {} \;
        fi
    else
        echo "Directory does not exist, skipping: $dir"
    fi
}

echo "Updating import paths and cleaning up..."

# Update import paths in framework files
echo "Updating import paths in framework files..."

# Update paths in framework/agents
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/agents" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/swarm
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/swarm" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/blockchain
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/blockchain" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/bridges
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/bridges" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/dex
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/dex" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/storage
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/storage" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/price
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/price" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/trading
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../visualization/" "include(\"../visualization/"
find_and_update_imports "$SRC_DIR/framework/trading" "include(\"../api/" "include(\"../../core/api/"

# Update paths in framework/visualization
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../core/" "include(\"../../core/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../agents/" "include(\"../agents/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../swarm/" "include(\"../swarm/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../blockchain/" "include(\"../blockchain/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../bridges/" "include(\"../bridges/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../dex/" "include(\"../dex/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../storage/" "include(\"../storage/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../price/" "include(\"../price/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../trading/" "include(\"../trading/"
find_and_update_imports "$SRC_DIR/framework/visualization" "include(\"../api/" "include(\"../../core/api/"

# Update paths in CLI files
echo "Updating import paths in CLI files..."
find_and_update_imports "$SRC_DIR/cli" "include(\"../core/" "include(\"../core/"
find_and_update_imports "$SRC_DIR/cli" "include(\"../api/" "include(\"../core/api/"

# Update using statements in all files
echo "Updating using statements in all files..."
find_and_update_imports "$SRC_DIR" "using .API" "using .API"
find_and_update_imports "$SRC_DIR" "using .CommandHandler" "using .CommandHandler"

echo "Import paths updated!"

# Clean up duplicate modules
echo "Cleaning up duplicate modules..."

# Check for duplicate modules
if [ "$DRY_RUN" = false ]; then
    echo "Checking for duplicate modules..."
    
    # Find all module declarations
    MODULE_DECLARATIONS=$(find "$SRC_DIR" -type f -name "*.jl" -exec grep -l "^module " {} \; | sort)
    
    # Extract module names
    MODULE_NAMES=$(find "$SRC_DIR" -type f -name "*.jl" -exec grep "^module " {} \; | sed 's/module \([A-Za-z0-9_]*\).*/\1/' | sort)
    
    # Find duplicate module names
    DUPLICATE_MODULES=$(echo "$MODULE_NAMES" | sort | uniq -d)
    
    if [ -n "$DUPLICATE_MODULES" ]; then
        echo "Found duplicate modules:"
        echo "$DUPLICATE_MODULES"
        
        echo "Files with duplicate module declarations:"
        for module in $DUPLICATE_MODULES; do
            echo "Module: $module"
            find "$SRC_DIR" -type f -name "*.jl" -exec grep -l "^module $module" {} \;
            echo ""
        done
    else
        echo "No duplicate modules found."
    fi
else
    echo "Would check for duplicate modules"
fi

echo "Update and cleanup complete!"
echo "Please review the changes and make any necessary adjustments."
