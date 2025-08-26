#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
# All settings are defined here for easy modification.

# URL for the standalone Python build. Must match Vercel's runtime architecture (x86_64).
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"

# Directory names for the Python runtime and its dependencies.
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"

# Vercel provides a persistent cache directory at `.vercel/cache`.
# We create a subdirectory within it to store our specific build artifacts.
readonly VERCEL_CACHE_DIR=".vercel/cache/bash/ytdlp-cache"
# A version file to invalidate the cache if we change dependencies or Python version.
# If this file exists, we assume the cache is valid.
readonly CACHE_VERSION_FILE="$VERCEL_CACHE_DIR/cache_version.txt"
readonly CURRENT_CACHE_VERSION="v1.0.0" # Increment this to force a rebuild


# --- Helper Functions ---

# A simple logging function to make build output clear.
log() {
  echo "--- $1 ---"
}

# Downloads, extracts, and prepares the standalone Python runtime.
# This function is only called on a cache miss.
setup_python_runtime() {
  log "Setting up Python runtime from scratch"
  local filename
  filename=$(basename "$PYTHON_URL")

  log "Downloading Python from $PYTHON_URL"
  curl --retry 3 -L -o "$filename" "$PYTHON_URL"

  # The archive contains symlinks which can cause issues. We extract and then
  # perform a deep copy (-L) to resolve all symlinks into actual files.
  log "Extracting and resolving symlinks"
  local temp_extract_dir="python_temp_extracted"
  tar -xzf "$filename" -C . # Extract to current dir, creates 'python' folder
  mv "$PYTHON_DIR" "$temp_extract_dir" # Rename to avoid conflict
  mkdir "$PYTHON_DIR" # Create the final clean directory
  cp -RL "$temp_extract_dir"/* "$PYTHON_DIR"/

  log "Setting execute permissions on Python binaries"
  chmod -R +x "$PYTHON_DIR/bin"

  log "Cleaning up intermediate download files"
  rm -rf "$temp_extract_dir"
  rm "$filename"

  log "Python runtime setup complete"
}

# Installs Python packages into the dedicated dependencies directory.
# This function is only called on a cache miss.
install_python_dependencies() {
  log "Installing Python dependencies"
  mkdir "$DEPS_DIR"
  
  # Use the specific pip from our downloaded Python to install packages.
  # The --target flag installs them into a local directory, not a system path.
  "$PYTHON_DIR/bin/pip" install --target="$DEPS_DIR" yt-dlp
  
  log "Dependencies installed successfully"
}


# --- Vercel Build and Handler Functions ---

#
# build() runs ONCE during deployment to prepare the serverless function.
# It now includes logic to check for a cache before doing a full build.
#
function build() {
  log "Build Step Started"

  # Check if a valid cache exists.
  if [ -f "$CACHE_VERSION_FILE" ] && [ "$(cat "$CACHE_VERSION_FILE")" == "$CURRENT_CACHE_VERSION" ]; then
    log "CACHE HIT: Valid cache found. Restoring from cache."
    # Copy the cached directories into the current build environment.
    cp -R "$VERCEL_CACHE_DIR/$PYTHON_DIR" .
    cp -R "$VERCEL_CACHE_DIR/$DEPS_DIR" .
    log "Restoration from cache complete."
  else
    log "CACHE MISS: No valid cache found. Performing a fresh build."
    
    # Perform the full installation.
    setup_python_runtime
    install_python_dependencies

    # After a successful fresh build, populate the cache for the next deployment.
    log "Populating cache for future builds"
    mkdir -p "$VERCEL_CACHE_DIR"
    cp -R "$PYTHON_DIR" "$VERCEL_CACHE_DIR/"
    cp -R "$DEPS_DIR" "$VERCEL_CACHE_DIR/"
    # Write the version file to validate this cache.
    echo "$CURRENT_CACHE_VERSION" > "$CACHE_VERSION_FILE"
    log "Cache populated successfully."
  fi

  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
# This function does not need to change. It assumes the build() function
# has correctly placed the python and dependencies directories.
#
function handler() {
  # Add our custom Python's `bin` and dependencies to the environment.
  export PATH="$PWD/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="$PWD/$DEPS_DIR"

  # --- Your Custom Application Logic Goes Here ---

  # The following is a verification step. In a real application,
  # you would replace this with your yt-dlp logic.
  echo "--- Handler Invoked ---"
  
  # For API routes, it's better to return structured data like JSON.
  # The `http_response_json` function is provided by the Vercel runtime.sh.
  http_response_header "Content-Type" "application/json; charset=utf-8"
  
  # Run a Python script to get info and format it as JSON.
  python3 -c '
import sys
import platform
import json
import yt_dlp

try:
    info = {
        "message": "Environment verified successfully",
        "python_version": sys.version.split()[0],
        "platform": f"{platform.system()} {platform.machine()}",
        "ytdlp_version": yt_dlp.version.__version__
    }
except Exception as e:
    info = {
        "error": "Failed to import or use yt_dlp",
        "details": str(e)
    }

print(json.dumps(info, indent=2))
'
}
