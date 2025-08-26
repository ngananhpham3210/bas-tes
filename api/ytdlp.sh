#!/bin/bash

# ===================================================================
# BUILD FUNCTION
# This function is automatically executed by the Vercel builder.
# It runs in a temporary directory that will become /var/task.
# ===================================================================
function build() {
  echo "--- Building: Installing Standalone Python ---"

  # 1. Define the URL and the target directory
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  PYTHON_DIR=".import-cache/python"

  # 2. Create the target directory for Python extraction
  mkdir -p "$PYTHON_DIR"

  # 3. Download and extract the archive in one step
  echo "Downloading and extracting Python from $PYTHON_URL"
  curl -L "$PYTHON_URL" | tar zxvf - -C "$PYTHON_DIR" --strip-components=1

  # 4. (FIX) Ensure the target directory for the symlink exists
  # This directory is not created by the builder until AFTER this script runs.
  mkdir -p ".import-cache/bin"

  # 5. Symlink the python executable to the bin directory
  # This makes `python3` directly available in your handler's PATH.
  ln -s "../python/bin/python3" ".import-cache/bin/python3"
  
  echo "--- Python installation complete ---"
}


# ===================================================================
# HANDLER FUNCTION
# This is your serverless function handler.
# ===================================================================
function handler() {
  # Now you can use python3 directly!
  local python_version
  python_version=$(python3 --version)

  http_response_header "Content-Type" "text/plain"
  echo "Hello from Bash!"
  echo "Python is available: $python_version"
}
