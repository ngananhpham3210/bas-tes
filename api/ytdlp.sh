# In your api/index.sh or other entrypoint

function build() {
  echo "--- Build Step Started ---"
  local PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"

  # 1. DOWNLOAD the asset to the current directory.
  # This directory is the root of your final Lambda package.
  echo "Downloading Python standalone build..."
  curl -sfL -o python-standalone.tar.gz "$PYTHON_URL"
  echo "Download complete."

  # 2. EXTRACT the asset into a subdirectory, also in the current directory.
  echo "Extracting Python..."
  mkdir -p python
  tar -xzf ./python-standalone.tar.gz -C ./python --strip-components=1
  echo "Extraction complete."

  # 3. CLEAN UP the temporary archive.
  rm python-standalone.tar.gz

  # At this point, you have a `python/` directory in the build output.
  # The builder will automatically package it.
  echo "--- Build Step Finished ---"
}

function handler() {
  # The path is relative to the root of the Lambda package.
  RESPONSE=$(./python/bin/python3 -c "import sys; print(f'Hello from Python {sys.version}!')")

  http_response_code 200
  http_response_header "Content-Type" "text/plain"
  echo "$RESPONSE"
}
