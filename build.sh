#!/bin/bash

function tg_sendText() {
curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
-d "parse_mode=html" \
-d text="${1}" \
-d chat_id=$CHAT_ID \
-d "disable_web_page_preview=true"
}

function tg_sendFile() {
curl -F chat_id=$CHAT_ID -F document=@${1} -F parse_mode=markdown https://api.telegram.org/bot$BOT_TOKEN/sendDocument
}

tg_send_Text "Downloading ccache"
cd /tmp
rclone copy aosp:corvus_ccache.tar.gz /tmp/
tar xf corvus_ccache.tar.gz
rm -f corvus_ccache.tar.gz

mkdir -p ~/.config/rclone
echo "$rclone_config" > ~/.config/rclone/rclone.conf
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "$id_rsa" > ~/.ssh/id_rsa
echo "$id_rsa_pub" > ~/.ssh/id_rsa.pub
chmod 400 ~/.ssh/id_rsa
git config --global user.email "$user_email"
git config --global user.name "$user_name"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa
echo "$known_hosts" > ~/.ssh/known_hosts
echo "$user_credentials" > ~/.git-credentials && git config --global credential.helper store

tg_sendText "Syncing rom"
mkdir -p /tmp/rom
cd /tmp/rom
repo init --no-repo-verify --depth=1 -u https://github.com/Corvus-R/android_manifest.git -b 11 -g default,-device,-mips,-darwin,-notdefault
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j6 || repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j8

tg_sendText "Downloading trees"
git clone https://github.com/Gabriel260/android_hardware_samsung-2 hardware/samsung
git clone https://github.com/geckyn/android_kernel_samsung_exynos7885 kernel/samsung/exynos7885 --depth=1
git clone https://github.com/Gabriel260/android_device_samsung_a10-common -b corvus device/samsung
git clone https://github.com/Gabriel260/proprietary_vendor_samsung_a10-common vendor/samsung

# Prebuilt kernel patch
tg_sendText "Applying Patches"
cd vendor/corvus
git remote add k https://github.com/crdroidandroid/android_vendor_crdroid
git fetch k
git cherry-pick ef2ec82665c547bd9e6b05a45dbb2cc4fc1b06b4
cd -

tg_sendText "Lunching"
# Normal build steps
. build/envsetup.sh
lunch corvus_a10-userdebug
export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 20G
ccache -o compression=true
ccache -z

tg_sendText "Starting Compilation.."

mka bacon -j10 | tee build.txt

tg_sendText "Build completed! Uploading rom to gdrive"
rclone copy out/target/product/a10/*Unofficial* aosp:final -P || rclone copy out/target/product/a10/*Alpha*.zip aosp:final -P

(ccache -s && echo " " && free -h && echo " " && df -h && echo " " && ls -a out/target/product/a10/) | tee final_monitor.txt
tg_sendFile "final_monitor.txt"
tg_sendFile "build.txt"

#tg_sendText "Uploading new ccache to gdrive"
#cd /tmp
#tar --use-compress-program="pigz -k -1 " -cf corvus_ccache.tar.gz ccache
#rclone copy corvus_ccache.tar.gz aosp: -P

tg_sendText "All tasks finished"
