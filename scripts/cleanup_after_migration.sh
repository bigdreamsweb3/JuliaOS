#!/bin/bash

# cleanup_after_migration.sh
#
# This script removes the original files that have been migrated to the new structure.
#
# Usage:
#   ./cleanup_after_migration.sh [--dry-run]
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
            echo "Usage: ./cleanup_after_migration.sh [--dry-run]"
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

# Function to remove a directory if it exists
remove_if_exists() {
    if [ -d "$1" ]; then
        execute rm -rf "$1"
    else
        echo "Directory does not exist, skipping: $1"
    fi
}

# Function to remove a file if it exists
remove_file_if_exists() {
    if [ -f "$1" ]; then
        execute rm -f "$1"
    else
        echo "File does not exist, skipping: $1"
    fi
}

echo "Cleaning up migrated files..."

# Remove framework-specific directories that have been migrated
echo "Removing framework-specific directories..."
remove_if_exists "$SRC_DIR/agents"
remove_if_exists "$SRC_DIR/swarm"
remove_if_exists "$SRC_DIR/blockchain"
remove_if_exists "$SRC_DIR/bridges"
remove_if_exists "$SRC_DIR/dex"
remove_if_exists "$SRC_DIR/storage"

# Remove CLI-specific files that have been migrated
echo "Removing CLI-specific files..."
remove_if_exists "$SRC_DIR/api/rest/handlers"

echo "Cleanup complete!"
echo "The old files have been removed, and only the new structure remains."
echo "Please verify that everything is working correctly with the new structure."
