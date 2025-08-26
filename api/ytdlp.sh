# api/index.sh

# This `build` function will be executed by build.sh during the deployment.
function build() {
  echo "--- Build Step Started ---"

  # 1. DOWNLOAD
  # `import_file` downloads the tarball to the build cache and prints its path.
  # We capture that path in a variable.
  echo "Downloading Python standalone build..."
  PYTHON_TARBALL_PATH=$(import_file "https://github.com/astral-sh/python-build-standalone/releases/download/20250818/cpython-3.12.11+20250818-x86_64_v4-unknown-linux-gnu-install_only_stripped.tar.gz")
  echo "Python tarball cached at: $PYTHON_TARBALL_PATH"

  # 2. EXTRACT AND PREPARE
  # We are currently in a temporary, empty directory that will become the root
  # of our Lambda (excluding the bootstrap files). We create a `python`
  # subdirectory and extract the tarball's contents into it.
  echo "Extracting Python..."
  mkdir -p python
  tar -xzf "$PYTHON_TARBALL_PATH" -C ./python --strip-components=1
  echo "Extraction complete."

  echo "--- Build Step Finished ---"
  # At the end of this function, a `python` directory exists. The @vercel/bash
  # builder will automatically grab everything in this directory and include it
  # in the final Lambda deployment package.
}

# This `handler` function will be executed by runtime.sh inside the Lambda.
function handler() {
  # The `./python` directory we created during the build step is now available.
  # We can execute the python binary from there.
  RESPONSE=$(./python/bin/python3 -c "import sys; print(f'Hello from Python {sys.version}!')")

  http_response_code 200
  http_response_header "Content-Type" "text/plain"
  echo "$RESPONSE"
}
