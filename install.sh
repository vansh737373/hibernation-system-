#!/bin/bash

# ============================================================
# Hibernation System - PaperMC Egg Install Script
# https://github.com/vansh737373/hibernation-system-
# ============================================================

SCRIPT_DIR="$(pwd)"

display() {
    echo -e "\033c"
    echo "
    ==========================================================================

$(tput setaf 6)   Hibernation System - PaperMC Egg
$(tput setaf 6)   
$(tput setaf 6)   Auto-hibernate when no players are online.
$(tput setaf 6)   Auto-start when a player connects.
$(tput setaf 6)   PaperMC Only
    ==========================================================================
    "
}

forceStuffs() {
    cd "${SCRIPT_DIR}" || return
    mkdir -p plugins/noMemberShutdown
    curl -sL -o plugins/IdleServerShutdown-1.3.jar \
        https://cdn.modrinth.com/data/DgUoVPBP/versions/QucVTrXS/IdleServerShutdown-1.3.jar
    curl -sL -o plugins/noMemberShutdown/config.yml \
        https://raw.githubusercontent.com/vansh737373/hibernation-system-/main/config.yml
    echo "eula=true" > eula.txt
}

# Install jq for JSON parsing
installJq() {
    cd "${SCRIPT_DIR}" || return
    # Remove corrupt jq if it exists
    if [ -e "tmp/jq" ]; then
        if ! tmp/jq --help >/dev/null 2>&1; then
            echo "$(tput setaf 3)Corrupt jq detected, re-downloading..."
            rm -f tmp/jq
        fi
    fi
    if [ ! -e "tmp/jq" ]; then
        mkdir -p tmp
        curl -sL -o tmp/jq https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64
        chmod +x tmp/jq
    fi
}

jq() {
    tmp/jq "$@"
}

# Remove corrupt server.jar (tiny file = download error page, not a real jar)
cleanupCorruptFiles() {
    cd "${SCRIPT_DIR}" || return
    if [ -e "server.jar" ]; then
        SIZE=$(stat -c%s "server.jar" 2>/dev/null || stat -f%z "server.jar" 2>/dev/null || echo "0")
        if [ "$SIZE" -lt 1000000 ]; then
            echo "$(tput setaf 1)Corrupt server.jar detected (${SIZE} bytes). Removing..."
            rm -f server.jar
        fi
    fi
    if [ -e "lazymc" ]; then
        SIZE=$(stat -c%s "lazymc" 2>/dev/null || stat -f%z "lazymc" 2>/dev/null || echo "0")
        if [ "$SIZE" -lt 1000000 ]; then
            echo "$(tput setaf 1)Corrupt lazymc detected (${SIZE} bytes). Removing..."
            rm -f lazymc
        fi
    fi
}

# Download PaperMC server jar
downloadPaper() {
    cd "${SCRIPT_DIR}" || return
    installJq

    VER_EXISTS=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r --arg VERSION "$MINECRAFT_VERSION" '.versions[] | select(. == $VERSION)')
    LATEST_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions[-1]')

    if [ -n "${VER_EXISTS}" ]; then
        echo -e "$(tput setaf 2)Version is valid. Using version ${MINECRAFT_VERSION}"
    else
        echo -e "$(tput setaf 3)Specified version not found. Defaulting to latest: ${LATEST_VERSION}"
        MINECRAFT_VERSION=${LATEST_VERSION}
    fi

    BUILD_NUMBER=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds" | jq -r '.builds[-1].build')

    if [ -z "$BUILD_NUMBER" ] || [ "$BUILD_NUMBER" == "null" ]; then
        echo "$(tput setaf 1)ERROR: Could not find builds for PaperMC ${MINECRAFT_VERSION}"
        exit 1
    fi

    JAR_NAME="paper-${MINECRAFT_VERSION}-${BUILD_NUMBER}.jar"
    DOWNLOAD_URL="https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${BUILD_NUMBER}/downloads/${JAR_NAME}"

    echo "$(tput setaf 6)Downloading PaperMC ${MINECRAFT_VERSION} build ${BUILD_NUMBER}..."
    curl -sL -o server.jar "${DOWNLOAD_URL}"

    # Verify download
    SIZE=$(stat -c%s "server.jar" 2>/dev/null || stat -f%z "server.jar" 2>/dev/null || echo "0")
    if [ "$SIZE" -lt 1000000 ]; then
        echo "$(tput setaf 1)ERROR: server.jar download failed (${SIZE} bytes). Check your Minecraft version."
        rm -f server.jar
        exit 1
    fi

    echo "$(tput setaf 2)PaperMC downloaded successfully (${SIZE} bytes)"
}

# Launch server with optional hibernation support
launchJavaServer() {
    cd "${SCRIPT_DIR}" || return

    # Calculate memory flags (reserve 200MB for system overhead)
    if [ "${SERVER_MEMORY}" == "0" ] || [ -z "${SERVER_MEMORY}" ]; then
        memory_flag=""
    elif [ "${SERVER_MEMORY}" -le 256 ]; then
        memory_flag="-Xmx${SERVER_MEMORY}M"
    else
        memory=$((SERVER_MEMORY - 200))
        memory_flag="-Xmx${memory}M"
    fi

    CMD="java -Xms128M ${memory_flag} -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar server.jar nogui"

    if [ "${ENABLE_HIBERNATION}" == "1" ] || [ "${ENABLE_HIBERNATION}" == "true" ]; then
        if [ ! -e "lazymc" ]; then
            echo "$(tput setaf 3)Downloading lazymc for Hibernation support..."
            curl -sL -o lazymc https://github.com/timvisee/lazymc/releases/download/v0.2.11/lazymc-v0.2.11-linux-x64
            chmod +x lazymc
        fi

        if [ ! -x "lazymc" ]; then
            echo "$(tput setaf 1)ERROR: lazymc download failed. Starting without hibernation."
            eval ${CMD}
        else
            echo "$(tput setaf 2)Starting server with Hibernation support..."
            ./lazymc start -- ${CMD}
        fi
    else
        eval ${CMD}
    fi
}

optimizeJavaServer() {
    cd "${SCRIPT_DIR}" || return
    if ! grep -q "view-distance" server.properties 2>/dev/null; then
        echo "view-distance=6" >> server.properties
    fi
}

# ============================================================
# Main Execution
# ============================================================

cleanupCorruptFiles

if [ ! -e "server.jar" ]; then
    display
    sleep 1

    echo "$(tput setaf 3)Starting PaperMC ${MINECRAFT_VERSION} installation, please wait..."
    sleep 2

    forceStuffs
    downloadPaper
    display

    optimizeJavaServer
    launchJavaServer
else
    display
    forceStuffs
    launchJavaServer
fi
