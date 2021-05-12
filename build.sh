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

start() {
BUILD_START=$(date +"%s");
CCACHE_NAME=corvus_ccache.tar.gz
CCACHE_NEW=ccache1.tar.gz
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
}

dlccache() {
tg_sendText "Downloading ccache"
DLCCACHE_START=$(date +"%s");
cd /tmp
rclone copy aosp:$CCACHE_NAME /tmp/
tar xf $CCACHE_NAME
rm -f $CCACHE_NAME
DLCCACHE_END=$(date +"%s");
DIFF=$(($DLCCACHE_END - $DLCCACHE_START));
tg_sendText "ccache downloaded in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

sync() {
SYNC_START=$(date +"%s");
tg_sendText "Syncing rom"
mkdir -p /tmp/rom
cd /tmp/rom
repo init --no-repo-verify --depth=1 -u https://github.com/Corvus-R/android_manifest.git -b 11 -g default,-device,-mips,-darwin,-notdefault
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j10 || repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j16
SYNC_END=$(date +"%s");
DIFF=$(($SYNC_END - $SYNC_START));
tg_sendText "Sync completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

trees() {
TREES_START=$(date +"%s");
tg_sendText "Downloading trees"
git clone https://github.com/Gabriel260/android_hardware_samsung-2 hardware/samsung
git clone https://github.com/geckyn/android_kernel_samsung_exynos7885 kernel/samsung/exynos7885 --depth=1
git clone https://github.com/eurekadevelopment/android_device_samsung -b corvus-arm64 device/samsung
git clone https://github.com/eurekadevelopment/proprietary_vendor_samsung -b lineage-18.1-arm64 vendor/samsung
TREES_END=$(date +"%s");
DIFF=$(($TREES_END - $TREES_START));
tg_sendText "trees downloaded in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

# Prebuilt kernel patch
patches() {
PATCHES_START=$(date +"%s");
tg_sendText "Applying Patches"
cd vendor/corvus
git remote add k https://github.com/crdroidandroid/android_vendor_crdroid
git fetch k
git cherry-pick ef2ec82665c547bd9e6b05a45dbb2cc4fc1b06b4
cd -
cd frameworks/base/data/etc
rm -f com.android.systemui.xml
git clone https://github.com/Gabriel260/temp
mv temp/com.android.systemui.xml ./
rm -rf temp
chmod 0644 com.android.systemui.xml
cd -
cd vendor
rm -rf themes
git clone https://github.com/Gabriel260/android_vendor_themes themes --depth=1
cd -
rm -rf packages/inputmethods/LatinIME
git clone https://github.com/LineageOS/android_packages_inputmethods_LatinIME packages/inputmethods/LatinIME --depth=1
PATCHES_END=$(date +"%s");
DIFF=$(($PATCHES_END - $PATCHES_START));
tg_sendText "patches applied in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

lunch() {
tg_sendText "Lunching"
# Normal build steps
. build/envsetup.sh
mkdir -p /tmp/ccache
export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 20G
ccache -o compression=true
ccache -z
lunch corvus_a10-userdebug
}

tmate() {
tmate -S /tmp/tmate.sock new-session -d && tmate -S /tmp/tmate.sock wait tmate-ready && send_shell=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}') && tg_sendText "$send_shell" &>/dev/null && sleep 2h
}

build() {
tg_sendText "Starting Compilation..."
echo "mka bacon -j10 | tee build.txt" > build2.sh
chmod 0777 build2.sh
timeout 105m ./build2.sh
}

uprom() {
tg_sendText "Build completed! Uploading rom to gdrive"
rclone copy out/target/product/a10/*Unofficial*.zip aosp:final -P || rclone copy out/target/product/a10/*Alpha*.zip aosp:final -P
}

finalmonitor() {
(ccache -s && echo " " && free -h && echo " " && df -h && echo " " && ls -a out/target/product/a10/) | tee final_monitor.txt
tg_sendFile "final_monitor.txt"
tg_sendFile "build.txt"
}

upccache() {
tg_sendText "Uploading new ccache to gdrive"
cd /tmp
tar --use-compress-program="pigz -k -1 " -cf $CCACHE_NEW ccache
rclone copy $CCACHE_NEW aosp: -P
}

finish() {
BUILD_END=$(date +"%s");
DIFF=$(($BUILD_END - $BUILD_START));
tg_sendText "All tasks completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

# Call the functions
start
# dlccache
sync
trees
patches
lunch
# tmate
build
uprom
upccache
finalmonitor
finish
