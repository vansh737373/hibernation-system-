#!/bin/bash

display() {
    echo -e "\033c"
    echo "
    ==========================================================================

$(tput setaf 6)     
$(tput setaf 6)   Powered by FlareLax Free Hosting!
$(tput setaf 6)  
$(tput setaf 6)   
$(tput setaf 6)    
$(tput setaf 6) COPYRIGHT 2024 FlareLax
$(tput setaf 6) Exclusively maintained by FlareLax
$(tput setaf 6) FlareLax Custom Edition - PaperMC Only
    ==========================================================================
    "  
}

forceStuffs() {
mkdir -p plugins && mkdir -p plugins/noMemberShutdown
cd plugins && curl -O https://cdn.modrinth.com/data/DgUoVPBP/versions/QucVTrXS/IdleServerShutdown-1.3.jar && cd ../.
cd plugins && cd noMemberShutdown && curl -O https://raw.githubusercontent.com/vansh737373/hibernation-system-/main/config.yml && cd ../. && cd ../.
echo "eula=true" > eula.txt
}

# Install functions
installJq() {
if [ -e "tmp/jq" ]; then
  if ! tmp/jq --help >/dev/null 2>&1; then
    rm -f tmp/jq
  fi
fi
if [ ! -e "tmp/jq" ]; then
mkdir -p tmp
curl -s -o tmp/jq -L https://github.com/jqlang/jq/releases/download/jq-1.8.2/jq-linux-amd64
chmod +x tmp/jq
fi
}

if [ -e "server.jar" ]; then
    SIZE=$(stat -c%s "server.jar" 2>/dev/null || stat -f%z "server.jar" 2>/dev/null)
    if [ "$SIZE" -lt 1000000 ]; then
        echo "Corrupt server.jar detected (size $SIZE). Removing..."
        rm -f server.jar
    fi
fi

# Useful functions
jq() {
    tmp/jq "$@"
}

# Validation functions
validateJavaVersion() {
    if [ ! "$(command -v java)" ]; then
      echo "Java is missing! Please ensure the 'Java' Docker image is selected in the startup options and then restart the server."
      sleep 5
      exit
    fi

    
    installJq
    
    VER_EXISTS=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r --arg VERSION $MINECRAFT_VERSION '.versions[] | contains($VERSION)' | grep -m1 true)
	LATEST_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions' | jq -r '.[-1]')
}

# Launch functions
launchJavaServer() {

  
  # Remove 200 mb to prevent server freeze
  if [ "${SERVER_MEMORY}" == "0" ] || [ -z "${SERVER_MEMORY}" ]; then
      memory_flag=""
  elif [ "${SERVER_MEMORY}" -le 256 ]; then
      memory_flag="-Xmx${SERVER_MEMORY}M"
  else
      number=200
      memory=$((SERVER_MEMORY - number))
      memory_flag="-Xmx${memory}M"
  fi
  
  CMD="java -Xms128M ${memory_flag} -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true -jar server.jar nogui"
  
  if [ "${ENABLE_HIBERNATION}" == "1" ] || [ "${ENABLE_HIBERNATION}" == "true" ]; then
      if [ -e "lazymc" ]; then
          LAZYSIZE=$(stat -c%s "lazymc" 2>/dev/null || stat -f%z "lazymc" 2>/dev/null)
          if [ "$LAZYSIZE" -lt 1000000 ]; then
              echo "Corrupt lazymc detected (size $LAZYSIZE). Removing..."
              rm -f lazymc
          fi
      fi
      if [ ! -e "lazymc" ]; then
          echo "$(tput setaf 3)Downloading lazymc for Hibernation support..."
          curl -sL https://github.com/timvisee/lazymc/releases/download/v0.2.11/lazymc-v0.2.11-linux-x64 -o lazymc
          chmod +x lazymc
      fi
      ./lazymc start -- ${CMD}
  else
      eval ${CMD}
  fi
}

optimizeJavaServer() {
  echo "view-distance=6" >> server.properties
  
}

if [ ! -e "server.jar" ]; then
    display
    sleep 1

    echo "$(tput setaf 3)Starting the download for PaperMC ${MINECRAFT_VERSION} please wait"

    sleep 4

    forceStuffs
    
    installJq

    VER_EXISTS=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r --arg VERSION $MINECRAFT_VERSION '.versions[] | contains($VERSION)' | grep -m1 true)
	LATEST_VERSION=$(curl -s https://api.papermc.io/v2/projects/paper | jq -r '.versions' | jq -r '.[-1]')

	if [ "${VER_EXISTS}" == "true" ]; then
		echo -e "Version is valid. Using version ${MINECRAFT_VERSION}"
	else
		echo -e "Specified version not found. Defaulting to the latest paper version"
		MINECRAFT_VERSION=${LATEST_VERSION}
	fi
	
	BUILD_NUMBER=$(curl -s https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION} | jq -r '.builds' | jq -r '.[-1]')
	JAR_NAME=paper-${MINECRAFT_VERSION}-${BUILD_NUMBER}.jar
	DOWNLOAD_URL=https://api.papermc.io/v2/projects/paper/versions/${MINECRAFT_VERSION}/builds/${BUILD_NUMBER}/downloads/${JAR_NAME}
	
	curl -o server.jar "${DOWNLOAD_URL}"

    display
    
    echo -e ""
    
    optimizeJavaServer
    launchJavaServer
    forceStuffs
else
    if [ -e "server.jar" ]; then
        display   
        forceStuffs
        launchJavaServer
    fi
fi
