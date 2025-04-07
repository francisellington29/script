#!/bin/bash

# Nezha Client Setup Script
# This script sets up and runs the Nezha monitoring client

# Define constants
work_dir="/etc/sing-box"
NEZHA_SERVER=${NEZHA_SERVER:-''} # v1哪吒填写形式：nezha.abc.com:8008,v0哪吒填写形式：nezha.abc.com
NEZHA_PORT=${NEZHA_PORT:-''}                      # v1哪吒留空此项,v0哪吒agent端口为{443,8443,2053,2083,2087,2096}其中之一时自动开启tls
NEZHA_KEY=${NEZHA_KEY:-''}

# 在脚本稍后的位置，在实际使用这些变量之前再导出
export NEZHA_SERVER
export NEZHA_PORT
export NEZHA_KEY
# Check and install required dependencies
check_dependencies() {
    echo -e "\e[1;32mChecking dependencies...\e[0m"

    # Check for package manager
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt-get"
        INSTALL_CMD="apt-get update && apt-get install -y"
    elif command -v apk >/dev/null 2>&1; then
        PKG_MANAGER="apk"
        INSTALL_CMD="apk add --no-cache"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        INSTALL_CMD="yum install -y"
    else
        echo -e "\e[1;31mUnsupported package manager. Please install required packages manually.\e[0m"
        return
    fi

    # Check for required tools
    REQUIRED_PKGS=()

    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        REQUIRED_PKGS+=("curl")
        echo -e "\e[1;33mNeither curl nor wget found, curl will be installed.\e[0m"
    fi

    # Install missing packages if any
    if [ ${#REQUIRED_PKGS[@]} -gt 0 ]; then
        echo -e "\e[1;32mInstalling required packages: ${REQUIRED_PKGS[*]}\e[0m"
        $INSTALL_CMD ${REQUIRED_PKGS[*]}
        echo -e "\e[1;32mDependencies installed successfully.\e[0m"
    else
        echo -e "\e[1;32mAll required dependencies are already installed.\e[0m"
    fi
}

# Run dependency check
check_dependencies

# Create directory if it doesn't exist
mkdir -p "${work_dir}"

# Determine architecture and download URL
ARCH=$(uname -m)
if [ "$ARCH" == "arm" ] || [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    BASE_URL="https://arm64.ssss.nyc.mn"
elif [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x86_64" ] || [ "$ARCH" == "x86" ]; then
    BASE_URL="https://amd64.ssss.nyc.mn"
else
    echo -e "\e[1;31mUnsupported architecture: $ARCH\e[0m"
    exit 1
fi

# Prepare for Nezha agent download
if [ -n "$NEZHA_PORT" ]; then
    DOWNLOAD_URL="$BASE_URL/agent"
    BINARY_NAME="npm"
else
    DOWNLOAD_URL="$BASE_URL/v1"
    BINARY_NAME="php"
    # Create config file for offline mode
    cat >"${work_dir}/config.yaml" <<EOF
client_secret: ${NEZHA_KEY}
debug: false
disable_auto_update: true
disable_command_execute: false
disable_force_update: true
disable_nat: false
disable_send_query: false
gpu: false
insecure_tls: false
ip_report_period: 1800
report_delay: 1
server: ${NEZHA_SERVER}
skip_connection_count: false
skip_procs_count: false
temperature: false
tls: false
use_gitee_to_upgrade: false
use_ipv6_country_code: false
uuid: ${UUID}
EOF
fi

# Download Nezha agent
FILENAME="${work_dir}/${BINARY_NAME}"
if [ -e "$FILENAME" ]; then
    echo -e "\e[1;32m$FILENAME already exists, skipping download\e[0m"
else
    echo -e "\e[1;32mDownloading Nezha agent to $FILENAME\e[0m"
    if command -v curl >/dev/null 2>&1; then
        curl -L -sS -o "$FILENAME" "$DOWNLOAD_URL"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$FILENAME" "$DOWNLOAD_URL"
    else
        echo -e "\e[1;31mNeither curl nor wget available for downloading\e[0m"
        exit 1
    fi
    chmod 775 "$FILENAME"
fi

# Run Nezha agent
run_nezha() {
    # Check if we need TLS based on port
    tlsPorts=("443" "8443" "2096" "2087" "2083" "2053")
    if [[ "${tlsPorts[*]}" =~ "${NEZHA_PORT}" ]]; then
        NEZHA_TLS="--tls"
    else
        NEZHA_TLS=""
    fi

    # Run appropriate agent based on provided variables
    if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
        if [ -e "${work_dir}/npm" ]; then
            echo -e "\e[1;32mStarting Nezha agent in online mode\e[0m"
            nohup "${work_dir}/npm" -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_TLS} >/dev/null 2>&1 &
            sleep 2
            echo -e "\e[1;32mNezha agent is running\e[0m"
        else
            echo -e "\e[1;31mNezha agent binary not found at ${work_dir}/npm\e[0m"
        fi
    elif [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_KEY" ]; then
        if [ -e "${work_dir}/php" ]; then
            echo -e "\e[1;32mStarting Nezha agent in offline mode\e[0m"
            nohup "${work_dir}/php" -c ${work_dir}/config.yaml >/dev/null 2>&1 &
            sleep 2
            echo -e "\e[1;32mNezha agent is running\e[0m"
        else
            echo -e "\e[1;31mNezha agent binary not found at ${work_dir}/php\e[0m"
        fi
    else
        echo -e "\e[1;31mNEZHA variables are empty, cannot run Nezha agent\e[0m"
        echo -e "\e[1;33mPlease set NEZHA_SERVER, NEZHA_PORT, and NEZHA_KEY\e[0m"
    fi
}

# Run Nezha agent
run_nezha

echo -e "\e[1;32mNezha client setup completed\e[0m"
