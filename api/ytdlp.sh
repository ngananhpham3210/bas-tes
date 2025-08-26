# In your api/index.sh or other entrypoint

function build() {
  echo "--- Build Step Started ---"
  local PYTHON_URL="https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz"

  # 1. DOWNLOAD using curl
  # Use curl directly to download the file to a simple, predictable name.
  # -L follows redirects, which is crucial for GitHub releases.
  echo "Downloading Python standalone build with curl..."
  curl -L -o python-standalone.tar.gz "$PYTHON_URL"
  echo "Download complete."

  # 2. EXTRACT AND PREPARE
  # This part remains the same. The build script will package the resulting `python` directory.
  echo "Extracting Python..."
  mkdir -p python
  tar -xzf ./python-standalone.tar.gz -C ./python --strip-components=1
  echo "Extraction complete."

  # Clean up the downloaded archive
  rm python-standalone.tar.gz

  echo "--- Build Step Finished ---"
}

function handler() {
  # This handler works exactly as before, since the `python` directory
  # is correctly created during the build step.
  RESPONSE=$(./python/bin/python3 -c "import sys; print(f'Hello from Python {sys.version}!')")
  echo "$RESPONSE"
}
