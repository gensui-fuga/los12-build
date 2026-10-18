# ARES (TYH212U) LOS 19.1 编译完整操作手册

> 目标机：叔叔台式机（R5 + 32G 内存）
> 系统盘：SN580 1TB + USB 硬盘盒（300MB/s）
> 编译方式：分时段通宵编译，中断可续

---

## 阶段一：制作启动 U 盘（在你的 X230 上做）

```bash
# 1. 下载 Ubuntu 22.04 LTS
cd ~/ares-build/iso
wget https://mirrors.tuna.tsinghua.edu.cn/ubuntu-releases/22.04/ubuntu-22.04.5-desktop-amd64.iso

# 2. 插入 U 盘（8G+），确认设备名
lsblk

# 3. 写盘（把 /dev/sdX 换成你的 U 盘，千万别写错！）
sudo dd if=ubuntu-22.04.5-desktop-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

---

## 阶段二：准备 SN580（在你的 X230 上做）

```bash
# 1. 把 SN580 插进 USB 硬盘盒，连到 X230
lsblk -o NAME,SIZE,MODEL,TRAN

# 2. 确认是 sdb/sdc（不是 sda！）
# 3. 运行分区脚本
sudo ~/ares-build/scripts/03-prepare-sn580.sh /dev/sdb
```

脚本会划 1G EFI + 剩余全部 ext4。

---

## 阶段三：安装 Ubuntu 到 SN580（在叔叔家用）

1. 把 SN580 硬盘盒 + Ubuntu U 盘都插上叔叔的台式机
2. 开机狂按 **F12**（或 F2/Del，看主板品牌）进启动菜单
3. 选 **UEFI: 你的U盘**
4. 进 Ubuntu Live 桌面 → 双击 **Install Ubuntu**
5. 安装时选：
   - **Something else**（其他选项）
   - `/boot/efi` → 选 SN580 的 1G 分区（ARES_EFI）
   - `/` → 选 SN580 的 ext4 分区（ARES_ROOT），**不要勾选格式化**
   - **Boot loader 装到 SN580 这块盘**（`/dev/sdb`），不是他的硬盘
6. 用户名设 `ye`，密码你定
7. 装完重启，**拔掉 U 盘**，此时默认还是进他的 Windows

---

## 阶段四：装编译环境（Ubuntu 里）

```bash
# 1. 把脚本拷进来（或直接从 GitHub 拉）
cd ~
git clone https://github.com/gensui-fuga/los12-build.git ares-build

# 2. 装依赖
sudo ~/ares-build/scripts/00-install-deps.sh

# 3. 配 SSD 挂载优化（可选，USB 盘建议做）
sudo bash -c 'echo "vm.swappiness=10" >> /etc/sysctl.conf'
```

---

## 阶段五：编译

### 手动跑（推荐第一次）

```bash
~/ares-build/scripts/01-full-build.sh
```

**能中断吗？能。** 按 Ctrl+C 停掉，下次再跑会从断点继续（ninja 增量编译）。

### 自动跑（通宵模式）

```bash
sudo ~/ares-build/scripts/02-setup-autobuild.sh
systemctl enable ares-build
# 下次开机自动开始编译
```

---

## 时间预期

| 阶段 | 时长 |
|---|---|
| Ubuntu 安装 | 30 分钟 |
| 依赖安装 | 10 分钟 |
| 首次 repo sync（130G） | 2-4 小时（看网速） |
| 编译（USB 限速） | **12-16 小时** |
| **合计** | **分 2-3 晚** |

---

## 每晚上机流程

```bash
# 叔叔睡觉了，你开始
插 SN580 硬盘盒 → 开机按 F12 → 选 USB → 进 Ubuntu

# 跑编译
cd ~/ares-build/scripts && ./01-full-build.sh

# 拔盘走人前
sudo shutdown -h now   # 或直接长按电源
拔硬盘盒 → 恢复原状
```

**第二晚继续**：同样步骤，脚本自动续编。

---

## 产物位置

```
~/ares-result/
  lineage-19.1-*-ARES.zip   ← 刷机包
  boot.img
  recovery.img
  dtbo.img
```

---

## 故障排查

| 症状 | 原因 | 解法 |
|---|---|---|
| `lunch: command not found` | envsetup.sh 没加载 | `source build/envsetup.sh` |
| `VNDK version 30 not found` | 缺 prebuilts/vndk | manifest 里补，重 sync |
| sync 卡住 | 网络问题 | 脚本自带 5 次重试 |
| 编译 OOM | 内存不够 | 降 `-j`：`JOBS=4 ./01-full-build.sh` |
| USB 盘掉盘 | 硬盘盒供电不足 | 用带外接电源的硬盘盒或 USB 3.0 口 |

---

## ⚠ 风险提示

1. **别动他的系统盘** —— 脚本里 `03-prepare-sn580.sh` 有内置盘保护，但仍然要自己确认设备名
2. **BIOS 改启动项后记得改回来** —— 如果改了默认启动顺序，他开机会进不了 Windows
3. **编译时机器会非常烫** —— 通宵跑注意散热
4. **断电会丢进度** —— 建议接个 UPS，或接受重来

---

## 现在的代码树在哪

| 位置 | 内容 |
|---|---|
| `~/los12` | 本地 18G 源码树（够改代码） |
| `github.com/gensui-fuga/lineageos_ums9620` | 设备树 |
| `github.com/gensui-fuga/tianyi-kernel-ums9620` | 内核 CI |
| `github.com/gensui-fuga/los12-build` | manifest + workflow + 编译脚本 |
