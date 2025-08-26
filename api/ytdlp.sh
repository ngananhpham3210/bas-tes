#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"


# --- Helper Functions ---

log() {
  echo "--> $1"
}

# Helper to display a directory tree, using `tree` if available, else `ls`.
log_directory_tree() {
  local target_dir="$1"
  local depth_limit="${2:-2}" # Default depth limit for tree is 2

  if [ ! -d "$target_dir" ]; then
    log "Directory not found: $target_dir"
    return
  fi

  log "Listing contents of: $target_dir"
  if command -v tree &> /dev/null; then
    # Use tree for a clean view, limit depth to avoid excessive output
    tree -L "$depth_limit" "$target_dir"
  else
    # Fallback to ls for a recursive, detailed listing
    ls -laR "$target_dir"
  fi
}

setup_python_runtime() {
  log "Setting up Python runtime..."
  local filename
  filename=$(basename "$PYTHON_URL")
  log "Downloading Python from $PYTHON_URL"
  curl --retry 3 -L -o "$filename" "$PYTHON_URL"
  log "Extracting and resolving symlinks..."
  local temp_extract_dir="python_temp_extracted"
  tar -xzf "$filename" -C .
  mv "$PYTHON_DIR" "$temp_extract_dir"
  mkdir "$PYTHON_DIR"
  cp -RL "$temp_extract_dir"/* "$PYTHON_DIR"/
  log "Setting execute permissions on Python binaries..."
  chmod -R +x "$PYTHON_DIR/bin"
  log "Cleaning up intermediate files..."
  rm -rf "$temp_extract_dir"
  rm "$filename"
  log "Python runtime setup complete."
}

install_python_dependencies() {
  log "Installing Python dependencies..."
  mkdir "$DEPS_DIR"
  "$PYTHON_DIR/bin/pip" install --target="$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
}

setup_runtime_environment() {
  export PATH="$PWD/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="$PWD/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

function build() {
  log "Build Step Started"
  setup_python_runtime
  install_python_dependencies
  
  # --- LOGGING AT BUILD TIME ---
  echo
  log "--- Logging Build Environment Details ---"
  
  # 1. Log System Folder Structure
  log_directory_tree "/" 1 # Show top-level root directories
  log_directory_tree "." 3 # Show a deeper view of the current build directory

  # 2. Log Import Cache
  if [[ -n "${IMPORT_CACHE-}" && -d "$IMPORT_CACHE" ]]; then
    log_directory_tree "$IMPORT_CACHE" 4
  else
    log "Build-time import cache directory not found or IMPORT_CACHE is not set."
  fi
  
  log "--- End Build Environment Details ---"
  echo
  log "Build Step Finished"
}

function handler() {
  setup_runtime_environment

  # --- LOGGING AT RUNTIME ---
  echo
  log "--- Logging Runtime Environment Details ---"

  # 1. Log System Folder Structure
  # The Lambda root is '/', and our code is in the current directory (`pwd`), which is /var/task
  log_directory_tree "/" 1 # Show top-level root directories
  log_directory_tree "." 3 # Show the contents of the deployed function package (/var/task)

  # 2. Log Import Cache
  local runtime_cache_dir="./.import-cache"
  if [ -d "$runtime_cache_dir" ]; then
    log_directory_tree "$runtime_cache_dir" 4
  else
    log "Runtime import cache directory not found at: $runtime_cache_dir"
  fi

  log "--- End Runtime Environment Details ---"
  echo

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying yt-dlp installation..."
  python3 -c '
import sys
import platform
import yt_dlp

print(f"Hello from Python {sys.version.split()[0]}!")
print(f"Running on platform: {platform.system()} {platform.machine()}")
try:
    print(f"Successfully imported yt-dlp version: {yt_dlp.version.__version__}")
except Exception as e:
    print(f"Error importing or using yt_dlp: {e}")
'
  log "Handler Finished"
}
