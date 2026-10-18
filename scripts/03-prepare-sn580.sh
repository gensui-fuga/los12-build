#!/bin/bash
# ============================================================
#  SN580 (装 USB 盒) → Ubuntu 22.04 安装准备
#  作用: 把 SN580 划好分区、格式化、把系统装进去
#  用法: sudo ./03-prepare-sn580.sh /dev/sdX
# ============================================================
set -e

DEV="${1:-}"
if [ -z "$DEV" ]; then
    echo "用法: sudo $0 /dev/sdX"
    echo ""
    echo "可用磁盘:"
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v loop
    exit 1
fi
if [ "$EUID" -ne 0 ]; then echo "请用 sudo 运行"; exit 1; fi

# 安全检查：拒绝内置盘
if echo "$DEV" | grep -qE "/dev/(sda|nvme0n1)$"; then
    echo "❌ 拒绝操作 $DEV —— 疑似内置系统盘！"
    echo "   SN580 作为 USB 设备应是 sdb 或 sdc"
    lsblk -o NAME,SIZE,MODEL,TRAN
    exit 1
fi

echo "=============================================="
echo " 目标磁盘: $DEV"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "$DEV"
echo "=============================================="
read -p "确认要格式化 $DEV 为 ARES 编译盘？(输入 YES 继续) " CONFIRM
[ "$CONFIRM" != "YES" ] && { echo "已取消"; exit 1; }

echo "[1/4] 清空分区表..."
wipefs -a "$DEV"

echo "[2/4] 创建 GPT + 分区..."
parted -s "$DEV" mklabel gpt
# EFI 1G
parted -s "$DEV" mkpart primary fat32 1MiB 1025MiB
parted -s "$DEV" set 1 esp on
# 余下全部给 ext4
parted -s "$DEV" mkpart primary ext4 1025MiB 100%
sleep 2; partprobe "$DEV" 2>/dev/null || true; sleep 2

# 识别分区名（sdb1 或 nvme0n1p1）
if [ -b "${DEV}1" ]; then P1="${DEV}1"; P2="${DEV}2"
elif [ -b "${DEV}p1" ]; then P1="${DEV}p1"; P2="${DEV}p2"
else echo "❌ 分区创建失败"; lsblk "$DEV"; exit 1; fi

echo "[3/4] 格式化..."
mkfs.fat -F32 -n ARES_EFI "$P1"
mkfs.ext4 -L ARES_ROOT -m 1 -F "$P2"

echo "[4/4] 完成"
echo ""
echo "=============================================="
echo "  ✅ SN580 分区完成"
echo ""
echo "  EFI:  $P1  (FAT32, 1G, 标签 ARES_EFI)"
echo "  ROOT: $P2  (ext4, $(lsblk -no SIZE $P2), 标签 ARES_ROOT)"
echo ""
echo "  下一步: 用 Ubuntu 22.04 安装盘启动，选中这块盘安装"
echo "        安装时选 '其他选项'，手动指定:"
echo "        - /boot/efi → $P1"
echo "        - / → $P2  (不要格式化，ext4)"
echo "        - 引导器安装到 $DEV"
echo "=============================================="
