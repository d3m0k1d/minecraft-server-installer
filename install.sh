#!/bin/bash
function choose_version_family() {
    mapfile -t versions < <(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json \
        | jq -r '.versions[] | select(.type=="release") | .id' | sort -Vr)
    
    declare -A families_map=()
    
    for v in "${versions[@]}"; do
        if [[ "$v" =~ ^([0-9]+\.[0-9]+) ]]; then
            fam="${BASH_REMATCH[1]}"
        else
            fam="$v"
        fi
        families_map["$fam"]=1
    done
    
    # Преобразуем hashmap в массив и отсортируем по убыванию версии
    families=("${!families_map[@]}")
    IFS=$'\n' sorted_fams=($(sort -Vr <<<"${families[*]}"))
    unset IFS

    echo "Select Minecraft major.minor version family (e.g. 1.21):"
    select family in "${sorted_fams[@]}"; do
        if [[ -n "$family" ]]; then
            echo "You selected family $family"
            choose_patch_version "$family"
            break
        else
            echo "Invalid selection, try again."
        fi
    done
}

function choose_patch_version() {
    local family="$1"
    mapfile -t filtered_versions < <(printf '%s\n' "${versions[@]}" | grep "^$family")
    
    echo "Select exact Minecraft version in family $family:"
    select version in "${filtered_versions[@]}"; do
        if [[ -n "$version" ]]; then
            echo "You selected exact version: $version"
            # Здесь можно добавить логику установки серверного jar
            break
        else
            echo "Invalid selection, try again."
        fi
    done
}


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
                    mkdir -p Velocity
                    mv velocity.jar Velocity
                    choose_version_family
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
                    mkdir -p BungeeCord
                    mv BungeeCord.jar BungeeCord
                    choose_version_family
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