#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# This is a best practice for robust shell scripts.
set -euo pipefail

# --- Configuration ---
# All settings are defined here for easy modification.

# URL for the standalone Python build. Must match Vercel's runtime architecture (x86_64).
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"

# Directory names for the Python runtime and its dependencies.
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"


# --- Helper Functions ---

# A simple logging function to make build output clear.
log() {
  echo "--> $1"
}

# --- NEW: Function to inspect the import cache at build-time ---
log_build_cache_info() {
  log "Inspecting Build-Time Import Cache..."
  # The IMPORT_CACHE env var usually points to the cache directory.
  # We fall back to the known path if the variable isn't set.
  local cache_dir="${IMPORT_CACHE:-/vercel/work/.vercel/cache/bash}"

  if [ -d "$cache_dir" ]; then
    echo "Cache directory found at: $cache_dir"
    echo "--- Cache Contents (Build Time) ---"
    # Recursively list the contents to show the structure.
    ls -lR "$cache_dir"
    echo "-----------------------------------"
  else
    echo "Build-time import cache directory not found at $cache_dir."
  fi
  echo
}

# --- NEW: Function to inspect the import cache at runtime ---
log_runtime_cache_info() {
  log "Inspecting Runtime Import Cache..."
  # At runtime, the cache is packaged into the function at this relative path.
  local cache_dir="./.import-cache"
  
  if [ -d "$cache_dir" ]; then
    echo "Cache directory found at: $cache_dir"
    echo "--- Cache Contents (Runtime) ---"
    # Recursively list the contents.
    ls -lR "$cache_dir"
    echo "--------------------------------"
  else
    echo "Runtime import cache directory not found at $cache_dir."
  fi
  echo
}

# Downloads, extracts, and prepares the standalone Python runtime.
setup_python_runtime() {
  # (This function is unchanged from the previous version)
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

# Installs Python packages into the dedicated dependencies directory.
install_python_dependencies() {
  # (This function is unchanged)
  log "Installing Python dependencies..."
  mkdir "$DEPS_DIR"
  "$PYTHON_DIR/bin/pip" install --target="$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
}

# Sets the necessary environment variables for our custom Python runtime.
setup_runtime_environment() {
  # (This function is unchanged)
  export PATH="$PWD/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="$PWD/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

#
# build() runs ONCE during deployment to prepare the serverless function.
#
function build() {
  log "Build Step Started"
  
  # --- ADDED CALL ---
  log_build_cache_info
  
  setup_python_runtime
  install_python_dependencies
  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
#
function handler() {
  # First, set up the environment so our custom Python is used.
  setup_runtime_environment

  # --- ADDED CALL ---
  log_runtime_cache_info

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying Python environment..."
  echo "Runtime Architecture: $(uname -m)"
  echo "Python Version: $(python3 --version)"
  echo
  log "Running verification script..."
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
  echo
  log "Handler Finished"
}
