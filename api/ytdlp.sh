#!/bin/bash

# ===================================================================
# BUILD FUNCTION
# ===================================================================
function build() {
  echo "--- Building: Installing Standalone Python ---"

  # 1. Define URLs and paths
  PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"
  PYTHON_DIR=".import-cache/python-3.12"

  # 2. Create the target directory and extract Python
  mkdir -p "$PYTHON_DIR"
  echo "Downloading and extracting Python from $PYTHON_URL"
  curl -L "$PYTHON_URL" | tar zxvf - -C "$PYTHON_DIR" --strip-components=1

  # 3. (FIX) Modify runtime.sh to prepend the Python bin directory to the PATH.
  # We use careful quoting to ensure $LAMBDA_TASK_ROOT is NOT expanded at build time,
  # but $PYTHON_DIR IS expanded.
  # '...' -> Literal string
  # "..." -> Allows variable expansion
  sed -i '2 a\
export PATH="$LAMBDA_TASK_ROOT/'"$PYTHON_DIR"'/bin:$PATH"\
' ".import-cache/runtime.sh"

  echo "--- Python installation complete ---"
}


# ===================================================================
# HANDLER FUNCTION
# ===================================================================
function handler() {
  # Now python, yt-dlp, etc. are all directly available!
  local python_version
  python_version=$(python3 --version)

  http_response_header "Content-Type" "text/plain"
  echo "Hello from Bash!"
  echo "Python is available: $python_version"
}
