#!/bin/bash
# ============================================================
#  Ubuntu 22.04 AOSP 编译依赖安装
#  用法: sudo ./00-install-deps.sh
# ============================================================
set -e
if [ "$EUID" -ne 0 ]; then echo "请用 sudo 运行"; exit 1; fi

echo "=== 更新软件源 ==="
apt-get update -qq

echo "=== 安装 AOSP 编译依赖 ==="
apt-get install -y -qq \
    bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
    git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev \
    lib32z1-dev libelf-dev liblz4-tool libncurses5 libncurses5-dev \
    libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush \
    rsync schedtool squashfs-tools xsltproc zip zlib1g-dev \
    python3 python-is-python3 lz4 zram-tools

echo "=== 安装 repo 工具 ==="
mkdir -p /usr/local/bin
curl -s https://storage.googleapis.com/git-repo-downloads/repo > /usr/local/bin/repo
chmod a+x /usr/local/bin/repo

echo "=== 配置 zram (USB 启动慢，用内存压缩减少 swap 卡顿) ==="
cat > /etc/default/zramswap <<'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
systemctl enable zramswap 2>/dev/null || true

echo "=== 关闭自动挂起/睡眠 (通宵编译) ==="
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true

echo ""
echo "✅ 依赖安装完成"
echo "   现在可以运行: ./01-full-build.sh"
