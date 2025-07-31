#!/bin/bash
# --- Version compare ---
function version_ge() {
    [[ "$(printf '%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

selected_version=""

function choose_version_family() {
    mapfile -t versions < <(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json \
        | jq -r '.versions[] | select(.type=="release") | .id' | sort -Vr)

    declare -A families_map=()
    filtered_versions=()
    for v in "${versions[@]}"; do
        if version_ge "$v" "1.3"; then
            filtered_versions+=("$v")
        fi
    done

    if [[ ${#filtered_versions[@]} -eq 0 ]]; then
        echo "No stable versions found >= 1.3"
        exit 1
    fi

    for v in "${filtered_versions[@]}"; do
        if [[ "$v" =~ ^([0-9]+\.[0-9]+) ]]; then
            fam="${BASH_REMATCH[1]}"
        else
            fam="$v"
        fi
        families_map["$fam"]=1
    done

    families=("${!families_map[@]}")
    IFS=$'\n' sorted_fams=($(sort -Vr <<<"${families[*]}"))
    unset IFS

    echo "Select Minecraft major.minor version family (e.g. 1.21):"
    select family in "${sorted_fams[@]}"; do
        if [[ -n "$family" ]]; then
            choose_patch_version "$family" "${filtered_versions[@]}"
            break
        else
            echo "Invalid selection, try again."
        fi
    done
}

function choose_patch_version() {
    local family="$1"
    shift
    local all_versions=("$@")
    mapfile -t filtered_versions < <(printf '%s\n' "${all_versions[@]}" | grep "^$family")

    echo "Select exact Minecraft version in family $family:"
    select version in "${filtered_versions[@]}"; do
        if [[ -n "$version" ]]; then
            selected_version="$version"
            echo "You selected exact version: $selected_version"
            choose_core_and_download "$selected_version"
            break
        else
            echo "Invalid selection, try again."
        fi
    done
}

function get_paper_download_url() {
    local version="$1"

    local builds_json=$(curl -s "https://api.papermc.io/v2/projects/paper/versions/$version/builds")

    local builds_count=$(echo "$builds_json" | jq '.builds | length')

    if [[ "$builds_count" -eq 0 ]]; then
        echo ""
        return 1
    fi

    local latest_build=$(echo "$builds_json" | jq '.builds | max')

    echo "https://api.papermc.io/v2/projects/paper/versions/$version/builds/$latest_build/download"
}


function choose_core_and_download() {
    local version="$1"
    declare -A core_links
    declare -a core_names

    # Vanilla
    local vanilla_url=$(curl -s https://launchermeta.mojang.com/mc/game/version_manifest.json | jq -r --arg v "$version" '.versions[] | select(.id==$v) | .url' | xargs -I{} curl -s {} | jq -r '.downloads.server.url // empty')
    if [[ -n "$vanilla_url" ]]; then
        core_links["Vanilla"]="$vanilla_url"
        core_names+=("Vanilla")
    fi

    # Paper
    local paper_url=$(get_paper_download_url "$version")
    if [[ -n "$paper_url" ]]; then
        if curl --head --silent --fail "$paper_url" >/dev/null; then
            core_links["Paper"]="$paper_url"
            core_names+=("Paper")
        fi
    fi

    # Purpur
    local purpur_url="https://api.purpurmc.org/v2/purpur/$version/latest/download"
    if curl --head --silent --fail "$purpur_url" >/dev/null; then
        core_links["Purpur"]="$purpur_url"
        core_names+=("Purpur")
    fi

    if [[ ${#core_names[@]} -eq 0 ]]; then
        echo "No available cores found for Minecraft $version."
        return 1
    fi

    echo "Select core type for Minecraft $version:"
    select core in "${core_names[@]}"; do
        if [[ -n "$core" ]]; then
            echo "Selected core: $core"
            local url="${core_links[$core]}"
            local dirname="${core,,}-$version"
            local filename="${core,,}-$version.jar"

            mkdir -p "$dirname"
            echo "Downloading $core server to $dirname/$filename ..."
            curl -L --progress-bar -o "$dirname/$filename" "$url"
            if [[ $? -eq 0 ]]; then
                echo "Download completed successfully!"
            else
                echo "Error during download."
            fi
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
sudo apt install curl cron unzip screen jq -y

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

choose_version_family

echo
echo "Installer finished."
