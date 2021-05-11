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

cd /tmp/rom # Depends on where source got synced


git clone https://github.com/Gabriel260/android_hardware_samsung-2 hardware/samsung
git clone https://github.com/geckyn/android_kernel_samsung_exynos7885 kernel/samsung/exynos7885 --depth=1

sleep 10

tg_sendText "Lunching"
# Normal build steps
. build/envsetup.sh
lunch lineage_a10-userdebug
export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 20G
ccache -o compression=true
ccache -z

tg_sendText "Starting Compilation.."

# Compilation by parts if you get RAM issue but takes nore time!
#mka api-stubs-docs -j8
#mka system-api-stubs-docs -j8
#mka test-api-stubs-docs -j8
#mka bacon -j8 | tee build.txt

make bacon -j8 | tee build.txt

(ccache -s && echo '' && free -h && echo '' && df -h && echo '' && ls -a out/target/product/a10/) | tee final_monitor.txt
sleep 1s
tg_sendFile "final_monitor.txt"
sleep 2s
tg_sendFile "build.txt"
