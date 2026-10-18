#!/bin/bash
# ============================================================
#  开机自动编译 systemd 服务
#  作用: 插上 USB 开机后自动开编，跑完自动关机
#  用法: sudo ./02-setup-autobuild.sh
# ============================================================
set -e
if [ "$EUID" -ne 0 ]; then echo "请用 sudo 运行"; exit 1; fi

REAL_USER="${SUDO_USER:-ye}"
SCRIPT_PATH="/home/$REAL_USER/ares-build/scripts/01-full-build.sh"

cat > /etc/systemd/system/ares-build.service <<EOF
[Unit]
Description=ARES LineageOS Auto Build
After=network-online.target
Wants=network-online.target
# 只在 USB 启动时触发（检测根设备不是 sda 内置盘）
ConditionPathExists=$SCRIPT_PATH

[Service]
Type=oneshot
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=/home/$REAL_USER
Environment="HOME=/home/$REAL_USER"
ExecStartPre=/bin/sleep 15
ExecStart=$SCRIPT_PATH
RemainingAfterExit=yes
TimeoutStartSec=24h
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ares-build.service

echo "✅ 已安装开机自动编译服务"
echo ""
echo "开关命令:"
echo "  启用: systemctl enable ares-build.service"
echo "  禁用: systemctl disable ares-build.service"
echo "  查看: systemctl status ares-build"
echo "  日志: journalctl -u ares-build -f"
echo ""
echo "⚠ 注意: 默认不自动开机，因为叔叔用 Windows 时也会触发"
echo "        需要自动时手动 systemctl enable"
