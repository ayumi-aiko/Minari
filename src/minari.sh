#!/usr/bin/env bash
#
# Copyright (C) 2025 愛子あゆみ <ayumi.aiko@outlook.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

function abort() {
    echo -e "\e[0;31m$1\e[0;37m"
    # bad json?? idc
    rm -rf ./app/res/raw/resources_info.json
    exit 1
}

function build_and_sign() {
    local extracted_dir_path="$1"
    local app_path="$2"
    local apkFileName
    local signed_apk
    if [ -f "$extracted_dir_path/apktool.yml" ]; then 
        apkFileName=$(grep apkFileName $extracted_dir_path/apktool.yml | cut -c 14-1000)
    else 
        abort "- Invalid Apkfile path."
    fi
    rm -rf ${extracted_dir_path}/dist/*
    java -jar ./bin/apktool.jar build "${extracted_dir_path}" &>./BuildLogs
    java -jar ./bin/signer.jar --apk ${extracted_dir_path}/dist/*.apk &>>./BuildLogs
    signed_apk=$(find ${extracted_dir_path}/dist -name "*aligned-debugSigned.apk" | head -n 1)
    [ ! -f "$signed_apk" ] && abort "- Signing failed or APK not found."
    mv "$signed_apk" "$app_path/minari-cust-output.apk"
    rm -rf ${extracted_dir_path}/build ${extracted_dir_path}/dist/
}

function addWallpaperMetaData() {
    local value="$1" type="$2" index="$3" wallpaperPath="$4"
    type="$(echo "$type" | tr '[:upper:]' '[:lower:]')"
    local filename="wallpaper_${value}.png"
    local path isDefault which
    case "$type" in
        home)
            isDefault=true
            which=1
            the_homescreen_wallpaper_has_been_set=true
        ;;
        lock)
            isDefault=true
            which=2
            the_lockscreen_wallpaper_has_been_set=true
        ;;
        additionals)
            isDefault=false
            which=1
        ;;
        *)
            abort "- Unknown wallpaper type: $type"
        ;;
    esac
    cat >> "./app/res/raw/resources_info.json" << EOF
    {
        "isDefault": ${isDefault},
        "index": ${index},
        "which": ${which},
        "screen": 0,
        "type": 0,
        "filename": "${filename}",
        "frame_no": -1,
        "cmf_info": [""]
    }${special_symbol}
EOF
    if [ "${automatedCall}" == false ]; then
        printf " - Enter the path to the default ${type^} wallpaper: "
        read path
        [ -f "$path" ] && cp -af "$path" "./app/res/drawable-nodpi/${filename}"
        clear
    else
        [ -f "$wallpaperPath" ] && cp -af "$wallpaperPath" "./app/res/drawable-nodpi/${filename}"
    fi
}

function makeManually() {
    local special_index=00
    local the_homescreen_wallpaper_has_been_set=false
    local the_lockscreen_wallpaper_has_been_set=false
    printf "\e[1;36m - How many wallpapers do you need to add to the Wallpaper App?\e[0;37m "
    read wallpaper_count
    [[ "$wallpaper_count" =~ ^[0-9]+$ ]] || abort "- Invalid input. Please enter a valid number."
    clear
    rm -rf "./app/res/raw/resources_info.json"
    echo -e "{\n\t\"version\": \"0.0.1\",\n\t\"phone\": [" > ./app/res/raw/resources_info.json
    for ((i = 1; i <= wallpaper_count; i++)); do
        [ "$i" -ge 10 ] && special_index=0
        printf "\e[0;36m - Adding configurations for wallpaper_${special_index}${i}.png.\e[0;37m\n"
        special_symbol=$([[ $i -eq $wallpaper_count ]] && echo "" || echo ",")
        if [[ "$the_lockscreen_wallpaper_has_been_set" == true && "$the_homescreen_wallpaper_has_been_set" == true ]]; then
            addWallpaperMetaData "${special_index}${i}" "additionals" "$i"
        else
            clear
            echo -e "\e[1;36m - What do you want to do with wallpaper_${special_index}${i}.png?\e[0;37m"
            [[ "$the_lockscreen_wallpaper_has_been_set" == false ]] && echo "[1] - Set as default lockscreen wallpaper"
            [[ "$the_homescreen_wallpaper_has_been_set" == false ]] && echo "[2] - Set as default homescreen wallpaper"
            echo "[3] - Include in additional wallpapers"
            printf "\e[1;36mType your choice: \e[0;37m"
            read user_choice
            case "$user_choice" in
                1) 
                    if [ "$the_lockscreen_wallpaper_has_been_set" == "false" ]; then
                        addWallpaperMetaData "${special_index}${i}" "lock" "$i"
                    else
                        addWallpaperMetaData "${special_index}${i}" "additionals" "$i"
                    fi
                    ;;
                2) 
                    if [ "$the_homescreen_wallpaper_has_been_set" == "false" ]; then
                        addWallpaperMetaData "${special_index}${i}" "home" "$i"
                    else
                        addWallpaperMetaData "${special_index}${i}" "additionals" "$i"
                    fi
                    ;;
                3)
                    addWallpaperMetaData "${special_index}${i}" "additionals" "$i"
                    ;;
                *)
                    abort "Invalid response! Exiting..."
                    ;;
            esac
        fi
    done
    echo -e "  ]\n}" >> ./app/res/raw/resources_info.json
}

function makeAuto() {
    source ./auto.config
    rm -rf ./app/res/raw/resources_info.json
    echo -e "{\n\t\"version\": \"0.0.1\",\n\t\"phone\": [" > ./app/res/raw/resources_info.json
    local special_index=00
    local count=1
    local total=${#additionalWallpaperPathIndexes[@]}
    local special_symbol=","
    for j in "lock ${lockScreenWallpaperPath}" "home ${homeScreenWallpaperPath}"; do
        addWallpaperMetaData "${special_index}${count}" "$(echo ${j} | awk '{print $1}')" "${count}" "$(echo ${j} | awk '{print $2}')"
        count=$((count + 1))
    done
    for i in "${additionalWallpaperPathIndexes[@]}"; do
        special_symbol=$([[ $count -eq $((total + 2)) ]] && echo "")
        addWallpaperMetaData "${special_index}${count}" "additionals" "${count}" "$i"
        count=$((count + 1))
    done
    echo -e "  ]\n}" >> ./app/res/raw/resources_info.json
}

clear
if ! command -v java &>/dev/null; then
    echo -e "\e[1;36m - Please install openjdk or any java toolchain to continue.\e[0;37m"
    sleep 0.5
    exit 1
fi
for arg in "$@"; do
    case "${arg,,}" in
        --autogen)
            automatedCall=true
            makeAuto
            echo "- Building Minari...."
            build_and_sign "./app" "." || abort "- Failed build request, please try again."
            exit 0
        ;;
    esac
done
automatedCall=false
makeManually
echo -e "\e[0;31m######################################################################"
echo "#       __        ___    ____  _   _ ___ _   _  ____ _               #"
echo "#       \ \      / / \  |  _ \| \ | |_ _| \ | |/ ___| |              #"
echo "#        \ \ /\ / / _ \ | |_) |  \| || ||  \| | |  _| |              #"
echo "#         \ V  V / ___ \|  _ <| |\  || || |\  | |_| |_|              #"
echo "#          \_/\_/_/   \_\_| \_\_| \_|___|_| \_|\____(_)              #"
echo "######################################################################"
echo -e "\e[1;36m- Make sure to remove everything in /system/priv-app/wallpaper-res and copy minari-cust-output.apk to that folder."
echo -e "  The app is built and moved to: $(pwd)/minari-cust-output.apk\e[0;31m"
echo -e "  This script is still in beta. Please check \"res/raw/resources_info.json\" for any issues.\e[0;37m"