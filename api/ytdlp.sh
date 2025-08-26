#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
# All settings are defined here for easy modification.

# The Vercel builder provides the cache directory via the `IMPORT_CACHE` env var.
# We provide a default for local testing.
readonly VERCEL_CACHE_DIR="${IMPORT_CACHE:-.vercel_cache/bash}"

# URL for the standalone Python build. Must match Vercel's runtime architecture (x86_64).
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"

# Directory names for our tools. These will be created inside the cache.
readonly PYTHON_DIR_NAME="python_runtime"
readonly DEPS_DIR_NAME="python_deps"

# A "flag" file to check if the cache is populated.
readonly INSTALL_FLAG_FILE="$VERCEL_CACHE_DIR/install_complete.flag"

# At runtime, use the ephemeral /tmp directory for yt-dlp's own cache.
readonly RUNTIME_CACHE_DIR="/tmp/ytdlp_cache"


# --- Helper Functions ---

# A simple logging function to make output clear.
log() {
  echo "--> $1"
}

# This function runs only when the cache is empty. It performs the expensive
# download and installation steps directly into the Vercel cache directory.
setup_dependencies_from_scratch() {
  log "Cache is cold. Performing fresh installation into $VERCEL_CACHE_DIR..."

  # Ensure the cache directory exists and is clean for a fresh install.
  rm -rf "$VERCEL_CACHE_DIR"
  mkdir -p "$VERCEL_CACHE_DIR"

  local python_archive_path="$VERCEL_CACHE_DIR/python.tar.gz"

  # 1. Download Python
  log "Downloading Python from $PYTHON_URL"
  curl --retry 3 -L -o "$python_archive_path" "$PYTHON_URL"

  # 2. Extract and prepare Python
  # We extract, then do a deep copy (-L) to resolve all symlinks.
  log "Extracting and preparing Python runtime..."
  local temp_extract_dir="$VERCEL_CACHE_DIR/python_temp_extracted"
  mkdir -p "$temp_extract_dir"
  tar -xzf "$python_archive_path" -C "$temp_extract_dir"
  
  local final_python_path="$VERCEL_CACHE_DIR/$PYTHON_DIR_NAME"
  mkdir -p "$final_python_path"
  # The extracted folder is named 'python', copy its contents.
  cp -RL "$temp_extract_dir/python/"* "$final_python_path"/
  chmod -R +x "$final_python_path/bin"

  # 3. Install Python Dependencies
  log "Installing yt-dlp and its dependencies..."
  local final_deps_path="$VERCEL_CACHE_DIR/$DEPS_DIR_NAME"
  mkdir -p "$final_deps_path"
  "$final_python_path/bin/pip" install --target="$final_deps_path" yt-dlp

  # 4. Clean up and create the flag file
  log "Cleaning up intermediate files..."
  rm -rf "$temp_extract_dir"
  rm "$python_archive_path"
  
  log "Installation complete. Caching for future builds."
  touch "$INSTALL_FLAG_FILE"
}

# Creates symlinks from the current build directory to the cached directories.
# This makes the tools available to the handler without re-copying them.
link_dependencies_from_cache() {
  log "Linking dependencies from cache..."
  # Symlink the Python runtime and dependencies into the current directory.
  # The handler will expect to find them here.
  ln -s "$VERCEL_CACHE_DIR/$PYTHON_DIR_NAME" python
  ln -s "$VERCEL_CACHE_DIR/$DEPS_DIR_NAME" dependencies
}

# Sets the necessary environment variables for our custom Python runtime.
setup_runtime_environment() {
  # Add our custom Python's `bin` directory to the PATH.
  export PATH="$PWD/python/bin:$PATH"

  # Add our dependencies directory to Python's module search path.
  export PYTHONPATH="$PWD/dependencies"
}


# --- Vercel Build and Handler Functions ---

#
# build() runs ONCE during deployment. It leverages the Vercel cache.
#
function build() {
  log "Build Step Started"

  # The core caching logic:
  if [ -f "$INSTALL_FLAG_FILE" ]; then
    log "Cache is warm. Found flag file: $INSTALL_FLAG_FILE"
    log "Skipping download and installation."
    ls -la "$VERCEL_CACHE_DIR" # Log cache contents for debugging
  else
    setup_dependencies_from_scratch
  fi

  # Always link the cached directories into the current build output.
  link_dependencies_from_cache

  log "Build Step Finished"
}

#
# handler() runs for EVERY incoming request.
#
function handler() {
  # First, set up the environment so our custom Python is used.
  setup_runtime_environment

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying environment..."
  python3 --version
  python3 -c "import yt_dlp; print(f'Successfully imported yt-dlp version: {yt_dlp.version.__version__}')"

  # Ensure the runtime cache directory exists in the ephemeral /tmp space.
  mkdir -p "$RUNTIME_CACHE_DIR"
  
  log "Using runtime cache at: $RUNTIME_CACHE_DIR"
  log "Listing runtime cache contents before execution:"
  ls -la "$RUNTIME_CACHE_DIR"

  # Example: Run yt-dlp to get the title of a video.
  # We use --cache-dir to leverage the warm Lambda's /tmp directory for runtime caching.
  log "Executing yt-dlp..."
  local video_url="https://www.youtube.com/watch?v=dQw4w9WgXcQ"
  local video_title
  video_title=$(yt-dlp --get-title --cache-dir "$RUNTIME_CACHE_DIR" "$video_url")
  
  log "yt-dlp execution finished."
  log "Listing runtime cache contents after execution:"
  ls -la "$RUNTIME_CACHE_DIR"

  # Send a JSON response back to the client.
  # These http_* functions are provided by your runtime.sh
  http_response_code 200
  http_response_json
  echo "{\"title\":\"$video_title\"}"
}

# The Vercel runtime expects the script to either define `build` and `handler`
# or just be an executable script. By calling `"$@"` we allow the runtime
# to invoke the specific function it needs (e.g., `bash ytdlp.sh build`).
"$@"
