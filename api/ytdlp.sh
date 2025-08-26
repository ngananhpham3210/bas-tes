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

  # 2. Create the target directory
  mkdir -p "$PYTHON_DIR"

  # 3. Download and extract the archive in one step
  # - `curl -L`: Downloads the file, following redirects.
  # - `tar zxvf -`: Extracts the gzipped tar archive from standard input (-).
  # - `-C "$PYTHON_DIR"`: Extracts the files into our target directory.
  # - `--strip-components=1`: Removes the top-level directory (e.g., `python/`) from the archive.
  echo "Downloading and extracting Python from $PYTHON_URL"
  curl -L "$PYTHON_URL" | tar zxvf - -C "$PYTHON_DIR" --strip-components=1

  # 4. (Optional but Recommended) Symlink the python executable to the bin directory
  # The bootstrap script adds .import-cache/bin to the PATH.
  # This makes `python3` directly available in your handler.
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
