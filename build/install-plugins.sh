#!/usr/bin/env bash
#
# Installs the Pact plugins required by the test suite into the Pact plugin
# directory (~/.pact/plugins by default, or $PACT_PLUGIN_DIR if set).
#
# The plugin driver will auto-download missing plugins on first use, but when
# several test projects run in parallel they race each other: one process
# writes the plugin manifest while another sees the manifest, assumes the
# plugin is installed, and fails to start the not-yet-downloaded binary.
# Installing up front avoids that race.
set -euo pipefail

PROTOBUF_PLUGIN_VERSION="0.8.0"

GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CLEAR="\e[0m"

plugins_dir="${PACT_PLUGIN_DIR:-$HOME/.pact/plugins}"

detect_os() {
    case "$OSTYPE" in
        linux*)          echo "linux" ;;
        darwin*)         echo "macos" ;;
        msys*|cygwin*|win32) echo "windows" ;;
        *)
            echo "Unsupported OS: $OSTYPE" >&2
            exit 1
            ;;
    esac
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)    echo "x86_64" ;;
        aarch64|arm64)   echo "aarch64" ;;
        *)
            echo "Unsupported architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

sha256_of() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        shasum -a 256 "$1" | cut -d ' ' -f 1
    else
        sha256sum "$1" | cut -d ' ' -f 1
    fi
}

# install_plugin <name> <version> <base-url> <binary-prefix>
#
# Downloads the plugin manifest and the platform-specific binary for the
# given plugin release into "$plugins_dir/<name>-<version>".
install_plugin() {
    name="$1"
    version="$2"
    base_url="$3"
    binary="$4"

    os=$(detect_os)
    arch=$(detect_arch)

    extension=""
    if [[ "$os" == "windows" ]]; then
        extension=".exe"
    fi

    # e.g.
    #   pact-protobuf-plugin-linux-aarch64.gz
    #   pact-protobuf-plugin-macos-x86_64.gz
    #   pact-protobuf-plugin-windows-x86_64.exe.gz
    src_file="$binary-$os-$arch$extension"
    src_archive="$src_file.gz"
    dest_file="$binary$extension"
    plugin_dir="$plugins_dir/$name-$version"

    echo -e "Installing Pact plugin ${YELLOW}$name $version${CLEAR} for ${YELLOW}$os/$arch${CLEAR}"
    echo -e "    Destination: ${BLUE}$plugin_dir${CLEAR}"

    if [[ -x "$plugin_dir/$dest_file" ]]; then
        echo -e "    Already installed, ${GREEN}skipping${CLEAR}"
        echo ""
        return
    fi

    mkdir -p "$plugin_dir"
    pushd "$plugin_dir" > /dev/null

    echo -e "    URL: ${BLUE}$base_url/$src_archive${CLEAR}"

    echo -n "    Downloading... "
    curl --silent --fail -L "$base_url/$src_archive" -o "$src_archive"
    curl --silent --fail -L "$base_url/$src_archive.sha256" -o "$src_archive.sha256"
    echo -e "${GREEN}OK${CLEAR}"

    # The published .sha256 files contain an absolute path from the release
    # machine, so compare the hash directly instead of using --check
    echo -n "    Verifying... "
    expected=$(cut -d ' ' -f 1 "$src_archive.sha256")
    actual=$(sha256_of "$src_archive")
    if [[ "$expected" != "$actual" ]]; then
        echo "FAILED (expected $expected, got $actual)" >&2
        exit 1
    fi
    echo -e "${GREEN}OK${CLEAR}"

    echo -n "    Extracting... "
    gunzip -f "$src_archive"
    mv "$src_file" "$dest_file"
    chmod +x "$dest_file"
    rm "$src_archive.sha256"
    echo -e "${GREEN}OK${CLEAR}"

    # The manifest is written last so a partially-installed plugin is never
    # mistaken for a complete one by the plugin driver
    echo -n "    Writing manifest... "
    curl --silent --fail -L "$base_url/pact-plugin.json" -o "pact-plugin.json"
    echo -e "${GREEN}OK${CLEAR}"
    echo ""

    popd > /dev/null
}

install_plugin "protobuf" "$PROTOBUF_PLUGIN_VERSION" \
    "https://github.com/pactflow/pact-protobuf-plugin/releases/download/v-$PROTOBUF_PLUGIN_VERSION" \
    "pact-protobuf-plugin"

echo "Successfully installed Pact plugins"
