#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# User-configurable variables (must start with APTLY_)
# ============================================================

# Target release tag, without "v"
APTLY_TAG="1.6.2"

# SHA256 checksums for the release zip files
# Fill in the exact 64-hex-character SHA256 values for the given tag
APTLY_SHA256_AMD64="c180d6d3c1e78f08a9e36cb07f64f3d98a5dba4111b02f58050b06f220a76c15"
APTLY_SHA256_ARM64="6fe08d26a2d2a84ce91630e72122495ed76157f02dff172cfa83c06ae4deb70c"

# ============================================================
# Internal configuration
# ============================================================

APTLY_REPO="aptly-dev/aptly"
APTLY_GITHUB_API="https://api.github.com"
APTLY_TMP="/tmp"
APTLY_WORKDIR="$(mktemp -d -p "$APTLY_TMP" aptly-install.XXXXXX)"

# Cleanup temporary directory on exit
cleanup() {
  rm -rf "$APTLY_WORKDIR"
}
trap cleanup EXIT

# Root privileges are required for installation paths
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: This script must be run as root (e.g. via sudo)." >&2
  exit 1
fi

# Detect system architecture
APTLY_UNAME_M="$(uname -m)"
case "$APTLY_UNAME_M" in
  x86_64)
    APTLY_ARCH="amd64"
    ;;
  aarch64|arm64)
    APTLY_ARCH="arm64"
    ;;
  *)
    echo "ERROR: Unsupported architecture: $APTLY_UNAME_M" >&2
    exit 1
    ;;
esac

echo "Detected architecture: $APTLY_ARCH"
echo "Target aptly tag: $APTLY_TAG"

# ------------------------------------------------------------
# Fetch release metadata for the specified tag using curl
# ------------------------------------------------------------

APTLY_RELEASE_JSON="$APTLY_WORKDIR/release.json"

curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  "$APTLY_GITHUB_API/repos/$APTLY_REPO/releases/tags/v$APTLY_TAG" \
  -o "$APTLY_RELEASE_JSON"

# Determine the correct asset name and download URL
APTLY_ZIP_NAME="aptly_${APTLY_TAG}_linux_${APTLY_ARCH}.zip"
APTLY_ZIP_URL="$(
  jq -r --arg name "$APTLY_ZIP_NAME" '
    .assets[]
    | select(.name == $name)
    | .browser_download_url
  ' "$APTLY_RELEASE_JSON"
)"

if [[ -z "$APTLY_ZIP_URL" || "$APTLY_ZIP_URL" == "null" ]]; then
  echo "ERROR: Release asset not found: $APTLY_ZIP_NAME" >&2
  exit 1
fi

echo "Downloading: $APTLY_ZIP_NAME"

# Download the zip file
APTLY_ZIP_PATH="$APTLY_WORKDIR/$APTLY_ZIP_NAME"
wget -O "$APTLY_ZIP_PATH" "$APTLY_ZIP_URL"

# Select expected SHA256 based on architecture
case "$APTLY_ARCH" in
  amd64)
    APTLY_EXPECTED_SHA256="$APTLY_SHA256_AMD64"
    ;;
  arm64)
    APTLY_EXPECTED_SHA256="$APTLY_SHA256_ARM64"
    ;;
esac

# Ensure SHA256 variables are properly set
if [[ "$APTLY_EXPECTED_SHA256" == "PUT_AMD64_ZIP_SHA256_HERE" || \
      "$APTLY_EXPECTED_SHA256" == "PUT_ARM64_ZIP_SHA256_HERE" ]]; then
  echo "ERROR: SHA256 checksum variable is not set correctly." >&2
  exit 1
fi

echo "Verifying SHA256 checksum"
echo "${APTLY_EXPECTED_SHA256}  ${APTLY_ZIP_PATH}" | sha256sum -c -

# Extract the zip archive
echo "Extracting archive"
unzip -q "$APTLY_ZIP_PATH" -d "$APTLY_WORKDIR"

APTLY_EXTRACT_DIR="$APTLY_WORKDIR/aptly_${APTLY_TAG}_linux_${APTLY_ARCH}"
if [[ ! -d "$APTLY_EXTRACT_DIR" ]]; then
  echo "ERROR: Expected extraction directory not found: $APTLY_EXTRACT_DIR" >&2
  exit 1
fi

# ============================================================
# Installation steps
# ============================================================

echo "Installing aptly binary to /usr/bin"
install -m 0755 "$APTLY_EXTRACT_DIR/aptly" /usr/bin/aptly

echo "Installing LICENSE to /usr/share/doc/aptly"
install -d -m 0755 /usr/share/doc/aptly
install -m 0644 "$APTLY_EXTRACT_DIR/LICENSE" /usr/share/doc/aptly/LICENSE

echo "Installing bash completion"
install -d -m 0755 /usr/share/bash-completion/completions
install -m 0644 \
  "$APTLY_EXTRACT_DIR/completion/bash_completion.d/aptly" \
  /usr/share/bash-completion/completions/aptly

aptly version

echo "Installation completed successfully."
echo "aptly version: $APTLY_TAG"
echo "architecture:  $APTLY_ARCH"
