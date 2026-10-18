#!/bin/bash
# ============================================================
#  ARES (TYH212U) LOS 19.1 编译 - 断点续编自动脚本
#  适用: 叔叔台式机 + SN580 USB 启动 + 分段编译
#  用法: sudo ./01-full-build.sh
# ============================================================
set -o pipefail

# ---------- 配置区 ----------
SRC_DIR="${SRC_DIR:-/home/ye/los12-src}"
CCACHE_DIR="${CCACHE_DIR:-$HOME/.ccache}"
LOG_DIR="$SRC_DIR/build-logs"
MANIFEST_URL="https://github.com/gensui-fuga/los12-build.git"
JOBS="${JOBS:-$(nproc --all)}"
# USB 盘编译时降低并行，避免 IO 饿死
if mount | grep -q "on / type"; then
    ROOT_DEV=$(findmnt -no SOURCE /)
    if echo "$ROOT_DEV" | grep -qE "sd[b-z]"; then
        echo "[!] 检测到 USB 启动，并行数降为 $((JOBS/2))"
        JOBS=$((JOBS/2))
    fi
fi

mkdir -p "$LOG_DIR" "$CCACHE_DIR"
exec > >(tee -a "$LOG_DIR/session-$(date +%Y%m%d_%H%M%S).log") 2>&1

echo "============================================================"
echo " ARES LOS 19.1 编译启动  $(date)"
echo " 源码目录: $SRC_DIR"
echo " 并行数:   $JOBS"
echo "============================================================"

# ---------- 1. 环境检查 ----------
echo "[1/6] 环境检查..."
for cmd in repo git ccache python3; do
    command -v $cmd >/dev/null || { echo "❌ 缺少 $cmd，请先运行 00-install-deps.sh"; exit 1; }
done

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
DISK_GB=$(df -BG "$SRC_DIR" 2>/dev/null | awk 'NR==2{gsub("G","");print $4}' || echo 0)
echo "  内存: ${MEM_GB}G  可用磁盘: ${DISK_GB}G"
[ "$MEM_GB" -lt 15 ] && echo "⚠ 内存不足 16G，将自动降并行并启用 zram"

# ---------- 2. 源码同步(断点续传) ----------
echo "[2/6] 源码同步..."
if [ ! -d "$SRC_DIR/.repo" ]; then
    mkdir -p "$SRC_DIR" && cd "$SRC_DIR"
    repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 \
        --git-lfs --no-clone-bundle --depth=1 || exit 1
else
    cd "$SRC_DIR"
fi

mkdir -p .repo/local_manifests
if [ ! -f .repo/local_manifests/minimal.xml ]; then
    curl -sL "$MANIFEST_URL/raw/main/minimal.xml" -o .repo/local_manifests/minimal.xml || {
        echo "❌ manifest 下载失败"; exit 1; }
fi
echo "  manifest 项目数: $(grep -c '<project' .repo/local_manifests/minimal.xml)"

# 同步带重试，最多 5 次
for i in 1 2 3 4 5; do
    echo "  === sync 第 $i 次 ==="
    repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags \
        --optimized-fetch --prune && break
    echo "  ⚠ sync 失败，30 秒后重试"
    sleep 30
done
[ $? -ne 0 ] && { echo "❌ sync 5 次均失败，请检查网络"; exit 1; }

# ---------- 3. 构建环境 ----------
echo "[3/6] 配置构建环境..."
cd "$SRC_DIR"
export USE_CCACHE=1
export CCACHE_DIR
export CCACHE_EXEC=$(command -v ccache)
export CCACHE_MAXSIZE=40G
export CCACHE_COMPRESS=1
ccache -M 40G -o compression=true >/dev/null 2>&1
echo "  ccache 目录: $CCACHE_DIR ($(ccache -s 2>/dev/null | awk '/max size/{print $3}'))"

source build/envsetup.sh || exit 1
lunch lineage_ARES-userdebug 2>&1 | tail -5
if ! get_build_var TARGET_PRODUCT 2>/dev/null | grep -q ARES; then
    echo "❌ lunch 失败，检查设备树"; exit 1
fi
echo "  ✅ lunch OK: $(get_build_var TARGET_PRODUCT)"

# ---------- 4. 编译 ----------
echo "[4/6] 开始编译 (可随时 Ctrl+C 中断，下次续编)..."
START=$(date +%s)
mka bacon -j"$JOBS" 2>&1 | tee "$LOG_DIR/build-$(date +%Y%m%d_%H%M%S).log"
BUILD_RC=${PIPESTATUS[0]}
END=$(date +%s)
echo "[4/6] 编译结束 rc=$BUILD_RC 耗时 $(( (END-START)/60 )) 分钟"

if [ $BUILD_RC -ne 0 ]; then
    echo "❌ 编译失败，日志尾部:"
    tail -50 "$LOG_DIR"/build-*.log | tail -50
    echo ""
    echo "💡 中断续编: 重新运行本脚本即可，ninja 会从断点继续"
    exit $BUILD_RC
fi

# ---------- 5. 产物收集 ----------
echo "[5/6] 收集产物..."
OUT="$SRC_DIR/out/target/product/ARES"
RESULT_DIR="$HOME/ares-result"
mkdir -p "$RESULT_DIR"
cp -v "$OUT"/lineage-*.zip "$RESULT_DIR/" 2>/dev/null
cp -v "$OUT"/boot.img "$RESULT_DIR/" 2>/dev/null
cp -v "$OUT"/recovery.img "$RESULT_DIR/" 2>/dev/null
cp -v "$OUT"/dtbo.img "$RESULT_DIR/" 2>/dev/null
cp -v "$OUT"/super_empty.img "$RESULT_DIR/" 2>/dev/null
echo "  产物已复制到: $RESULT_DIR"
ls -lh "$RESULT_DIR"

# ---------- 6. 完成 ----------
echo "[6/6] ✅ 编译成功  $(date)"
echo ""
echo "============================================================"
echo "  下一步: 把 $RESULT_DIR 里的文件拷出来"
echo "  推荐拷到 U 盘或用 scp 传回 X230"
echo "============================================================"
