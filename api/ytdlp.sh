#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"

# --- Directory Naming ---
readonly PYTHON_DIR="python"
readonly DEPS_DIR="dependencies"

# --- Dynamic Paths (from Vercel Builder) ---
readonly PYTHON_CACHE_DIR="${IMPORT_CACHE}/${PYTHON_DIR}"


# --- Helper Functions ---

log() {
  echo "--> $1"
}

log_deployment_structure() {
  local target_dir="$1"
  if [ ! -d "$target_dir" ]; then log "Directory not found for structure log: $target_dir"; return; fi
  echo; echo "============================================================"
  echo "--- Structure of Deployment Directory: $target_dir"
  echo "--- (Excluding contents of '$PYTHON_DIR' and '$DEPS_DIR')"
  echo "============================================================"
  if command -v tree &> /dev/null; then
    tree -L 3 -I "$PYTHON_DIR|$DEPS_DIR" "$target_dir"
  else
    log "NOTE: 'tree' command not found. Falling back to 'ls'."
    ls -la "$target_dir"
  fi
  echo "--- End of Structure Log for: $target_dir ---"; echo "============================================================"; echo
}

log_directory_details_recursive() {
  local target_dir="$1"
  if [ ! -d "$target_dir" ]; then log "Skipping detailed log for non-existent directory: $target_dir"; return; fi
  echo; echo "============================================================"
  echo "--- Detailed Recursive Listing for: $target_dir"
  echo "============================================================"
  ls -laR "$target_dir"
  echo "--- End of Listing for: $target_dir ---"; echo "============================================================"; echo
}

# --- Standard Setup Functions ---

setup_runtime_environment() {
  # We still set the PATH so we can find `python3` easily.
  # And PYTHONPATH is critical for yt-dlp's imports to work.
  export PATH="/var/task/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="/var/task/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

function build() {
  log "Build Step Started"
  log "Build output directory is: $PWD"
  log "Vercel cache directory is: $IMPORT_CACHE"

  dnf install -y tree

  # --- Step 1: Ensure Python is in the Vercel Cache ---
  log "Checking for cached Python runtime at: $PYTHON_CACHE_DIR"
  if [ -x "$PYTHON_CACHE_DIR/bin/python3" ]; then
    log "Python found in cache. Skipping download."
  else
    log "Python not found in cache. Downloading and extracting..."
    local filename; filename=$(basename "$PYTHON_URL")
    mkdir -p "$PYTHON_CACHE_DIR"
    curl --retry 3 -L -o "$filename" "$PYTHON_URL"
    tar -xzf "$filename" -C "$PYTHON_CACHE_DIR" --strip-components=1
    rm "$filename"
    log "Python has been cached successfully."
  fi

  # --- Step 2: Copy Python from Cache to the Build Output Directory ---
  log "Copying Python runtime from cache to build output, dereferencing symlinks..."
  cp -RL "$PYTHON_CACHE_DIR" "./$PYTHON_DIR"
  log "Python copied to ./$PYTHON_DIR"

  # --- Step 3: Install Dependencies ---
  log "Installing Python dependencies into ./$DEPS_DIR..."
  "./$PYTHON_DIR/bin/pip" install --target="./$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."

  # --- Step 4: Move yt-dlp executable to .import-cache/bin ---
  log "Moving yt-dlp executable to .import-cache/bin..."
  mkdir -p "./.import-cache/bin"
  mv "./$DEPS_DIR/bin/yt-dlp" "./.import-cache/bin/"
  chmod +x "./.import-cache/bin/yt-dlp"
  log "yt-dlp executable moved successfully."
  
  log "Logging Final Build Environment Details..."
  log_deployment_structure "."
  log_directory_details_recursive "./.import-cache"
  
  log "Build Step Finished"
}

# --- MODIFIED HANDLER ---
function handler() {
  setup_runtime_environment

  log "Logging Runtime Environment Details..."
  log_deployment_structure "/var/task"
  log_directory_details_recursive "/var/task/.import-cache"

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying yt-dlp by executing it with python3..."

  # Define the full path to the script for clarity and robustness.
  local yt_dlp_script="/var/task/.import-cache/bin/yt-dlp"

  log "--- Verifying python3 can be found ---"
  which python3

  log "--- Verifying PYTHONPATH is set ---"
  echo "PYTHONPATH=$PYTHONPATH"
  
  log "--- Verifying yt-dlp script exists ---"
  ls -l "$yt_dlp_script"

  log "--- Executing yt-dlp --version with explicit python3 interpreter ---"
  # This is the key command: it uses our packaged python3 to run the script.
  # It works because PYTHONPATH is set, allowing the script to find its libraries.
  python3 "$yt_dlp_script" --version

  log "Handler Finished"
}
