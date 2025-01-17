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
CCACHE_NAME=corvus_arm64_ccache.tar.gz
# CCACHE_NEW=
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
tg_sendText "G: Downloading ccache"
DLCCACHE_START=$(date +"%s");
cd /tmp
rclone copy aosp:$CCACHE_NAME /tmp/
tar xf $CCACHE_NAME
rm -f $CCACHE_NAME
DLCCACHE_END=$(date +"%s");
DIFF=$(($DLCCACHE_END - $DLCCACHE_START));
tg_sendText "G: ccache downloaded in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

sync() {
SYNC_START=$(date +"%s");
tg_sendText "G: Syncing rom"
mkdir -p /tmp/rom
cd /tmp/rom
repo init --no-repo-verify --depth=1 -u https://github.com/AOSPA/manifest -b ruby -g default,-device,-mips,-darwin,-notdefault
repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j8 || repo sync -c --force-sync --optimized-fetch --no-tags --no-clone-bundle --prune -j22
SYNC_END=$(date +"%s");
DIFF=$(($SYNC_END - $SYNC_START));
tg_sendText "G: Sync completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

trees() {
TREES_START=$(date +"%s");
tg_sendText "GG: Downloading trees"
git clone https://github.com/Gabriel260/android_hardware_samsung-2 -b dp hardware/samsung
git clone https://github.com/geckyn/android_kernel_samsung_exynos7885 kernel/samsung/exynos7885 --depth=1
git clone https://github.com/Gabriel260/android_device_samsung_a10-common -b pa device/samsung
git clone https://github.com/Gabriel260/proprietary_vendor_samsung_a10-common vendor/samsung
TREES_END=$(date +"%s");
DIFF=$(($TREES_END - $TREES_START));
tg_sendText "G: trees downloaded in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

# Prebuilt kernel patch
patches() {
PATCHES_START=$(date +"%s");
tg_sendText "G: Applying Patches"
cd vendor
rm -rf pa
git clone https://github.com/Gabriel260/android_vendor_pa pa --depth=1
cd ..
cd vendor/qcom/build/tasks
rm -f kernel_definitions.mk
git clone https://github.com/Gabriel260/temp
mv temp/kernel_definitions.mk ./
chmod 0644 kernel_definitions.mk
rm -rf temp
cd -
PATCHES_END=$(date +"%s");
DIFF=$(($PATCHES_END - $PATCHES_START));
tg_sendText "G: patches applied in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

tmate() {
tmate -S /tmp/tmate.sock new-session -d && tmate -S /tmp/tmate.sock wait tmate-ready && send_shell=$(tmate -S /tmp/tmate.sock display -p '#{tmate_ssh}') && tg_sendText "$send_shell" &>/dev/null && sleep 2h
}

timeoutbuild() {
tg_sendText "G: Starting Compilation..."
echo "export CCACHE_DIR=/tmp/ccache" >> build2.sh
echo "export CCACHE_EXEC=$(which ccache)" >> build2.sh
echo "export USE_CCACHE=1" >> build2.sh
echo "ccache -M 20G" >> build2.sh
echo "ccache -o compression=true" >> build2.sh
echo "ccache -z" >> build2.sh
echo "source ./build/envsetup.sh" >> build2.sh
echo "lunch corvus_a10-userdebug" >> build2.sh
echo "mka bacon -j10 | tee build.txt" >> build2.sh
chmod 0777 build2.sh
timeout --preserve-status 100m ./build2.sh
}

build() {
tg_sendText "G: Starting Compilation..."
. build/envsetup.sh
export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 20G
ccache -o compression=true
ccache -z
lunch corvus_a10-userdebug
mka bacon -j10 | tee build.txt
}

uprom() {
tg_sendText "G: Build completed! Uploading rom to gdrive"
rclone copy out/target/product/a10/*Unofficial*.zip aosp:final -P || rclone copy out/target/product/a10/*Alpha*.zip aosp:final -P
}

finalmonitor() {
(ccache -s && echo " " && free -h && echo " " && df -h && echo " " && ls -a out/target/product/a10/) | tee final_monitor.txt
tg_sendFile "final_monitor.txt"
tg_sendFile "build.txt"
}

upccache() {
tg_sendText "G: Uploading new ccache to gdrive"
cd /tmp
tar --use-compress-program="pigz -k -1 " -cf $CCACHE_NEW ccache
rclone copy $CCACHE_NEW aosp: -P
}

finish() {
BUILD_END=$(date +"%s");
DIFF=$(($BUILD_END - $BUILD_START));
tg_sendText "G: All tasks completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds."
}

# Call the functions
start
# dlccache
#sync
#trees
#patches
tmate
# timeoutbuild
# build
#uprom
# upccache
#finalmonitor
#finish
