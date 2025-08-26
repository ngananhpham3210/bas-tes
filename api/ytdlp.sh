#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
readonly PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64-unknown-linux-gnu-install_only_stripped.tar.gz"

# --- Directory Naming ---
# Name of the directory for the Python runtime inside the cache AND the final lambda output
readonly PYTHON_DIR="python"
# Name of the directory for pip dependencies in the final lambda output
readonly DEPS_DIR="dependencies"

# --- Dynamic Paths (from Vercel Builder) ---
# The location within the Vercel cache where we will store Python between builds.
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
  # At runtime, the directories we created in the build output (`.` at build time)
  # will be at the root of the Lambda task (`/var/task`).
  export PATH="/var/task/$PYTHON_DIR/bin:$PATH"
  export PYTHONPATH="/var/task/$DEPS_DIR"
}


# --- Vercel Build and Handler Functions ---

function build() {
  log "Build Step Started"
  log "Build output directory is: $PWD"
  log "Vercel cache directory is: $IMPORT_CACHE"

  # Install `tree` for better logging during the build
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
    # --strip-components=1 removes the top-level folder from the tarball
    tar -xzf "$filename" -C "$PYTHON_CACHE_DIR" --strip-components=1
    rm "$filename"
    log "Python has been cached successfully."
  fi

  # --- Step 2: Copy Python from Cache to the Build Output Directory ---
  # This is the crucial step. Anything in the current directory ($PWD) gets packaged.
  log "Copying Python runtime from cache to build output directory..."
  cp -R "$PYTHON_CACHE_DIR" "./$PYTHON_DIR"
  log "Python copied to ./$PYTHON_DIR"

  # --- Step 3: Install Dependencies directly into the Build Output Directory ---
  log "Installing Python dependencies into ./$DEPS_DIR..."
  # Use the Python executable we just copied into the output directory
  "./$PYTHON_DIR/bin/pip" install --target="./$DEPS_DIR" yt-dlp
  log "Dependencies installed successfully."
  
  log "Logging Final Build Environment Details..."
  # Log the structure of the build output directory (`.`) which becomes `/var/task`
  log_deployment_structure "."
  # Log the full contents of the cache for debugging
  log_directory_details_recursive "$IMPORT_CACHE"
  
  log "Build Step Finished"
}

function handler() {
  setup_runtime_environment

  log "Logging Runtime Environment Details..."
  log_deployment_structure "/var/task"

  # --- Your Custom Application Logic Goes Here ---
  log "Handler invoked. Verifying yt-dlp installation..."
  python3 -c '
import sys
import os
import platform
import yt_dlp

print(f"Hello from Python {sys.version.split()[0]}!")
print(f"Python executable: {sys.executable}")
print(f"PATH: {os.environ.get(\"PATH\")}")
print(f"PYTHONPATH: {os.environ.get(\"PYTHONPATH\")}")
try:
    print(f"Successfully imported yt-dlp version: {yt_dlp.version.__version__}")
except Exception as e:
    print(f"Error importing or using yt_dlp: {e}")
'
  log "Handler Finished"
}
