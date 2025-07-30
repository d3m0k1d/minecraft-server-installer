#!/bin/bash
echo "Minecraft Server Installer"
cat << 'EOF'

   __  ___  _____   ____        ____   _  __   ____ ______   ___    __    __    ____   ___ 
  /  |/  / / ___/  / __/ ____  /  _/  / |/ /  / __//_  __/  / _ |  / /   / /   / __/  / _ \
 / /|_/ / / /__   _\ \  /___/ _/ /   /    /  _\ \   / /    / __ | / /__ / /__ / _/   / , _/
/_/  /_/  \___/  /___/       /___/  /_/|_/  /___/  /_/    /_/ |_|/____//____//___/  /_/|_| 
                                                                                           
                                                                                                             
EOF
echo "https://github.com/d3m0k1d/minecraft-server-installer"


echo "Installing dependencies..."
sudo apt install curl cron unzip screen -y

read -rp "Would you like to use a proxy server? (y/n): " answer

if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
    echo "Select the proxy server you want to use:"
    select proxy in "Velocity (1.20+)" "BungeeCord (Older versions)"; do
        case $proxy in
            "Velocity (1.20+)")
                echo "Downloading Velocity proxy..."
                curl -o velocity.jar -L "https://mineacademy.org/api/velocity/latest" -A "Minecraft Server Installer (https://github.com/d3m0k1d/minecraft-server-installer)"
                if [[ $? -eq 0 ]]; then
                    echo "Velocity downloaded successfully: velocity.jar"
                else
                    echo "Error downloading Velocity."
                fi
                break
                ;;
            "BungeeCord (Older versions)")
                echo "Downloading BungeeCord proxy..."
                BUILD_NUM=$(curl -s https://ci.md-5.net/job/BungeeCord/ | grep -Eo '/job/BungeeCord/[0-9]+/' | head -1 | grep -Eo '[0-9]+')
                JAR_URL="https://ci.md-5.net/job/BungeeCord/${BUILD_NUM}/artifact/bootstrap/target/BungeeCord.jar"
                curl -L -o BungeeCord.jar "$JAR_URL"
                if [[ $? -eq 0 ]]; then
                    echo "BungeeCord downloaded successfully: BungeeCord.jar"
                else
                    echo "Download failed."
                fi
                break
                ;;
            *)
                echo "Invalid selection, please try again."
                ;;
        esac
    done
else
    echo "Skipping proxy server installation."
fi

echo
echo "Installer finished."