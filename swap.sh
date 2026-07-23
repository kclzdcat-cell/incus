#!/usr/bin/env bash
set -Eeuo pipefail

SWAPFILE="/swapfile"

info() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*"; }
error() { echo "[ERROR] $*" >&2; }

if [[ $EUID -ne 0 ]]; then
    error "请使用 root 用户运行此脚本。"
    exit 1
fi

for command_name in swapon swapoff mkswap findmnt dd awk grep chmod df; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        error "缺少命令：$command_name"
        exit 1
    fi
done

info "检测系统中是否启用 $SWAPFILE ..."

if swapon --noheadings --raw --show=NAME 2>/dev/null | grep -Fxq "$SWAPFILE"; then
    warn "$SWAPFILE 目前正在作为 Swap 使用。"
    read -rp "是否关闭并取消开机自动启用？[y/N]: " disable_swapfile
    if [[ "$disable_swapfile" =~ ^[Yy]$ ]]; then
        swapoff "$SWAPFILE"
        if grep -Eq "^[[:space:]]*${SWAPFILE//\//\/}[[:space:]]" /etc/fstab; then
            cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
            sed -i "\|^[[:space:]]*${SWAPFILE//\//\/}[[:space:]]|d" /etc/fstab
        fi
        info "$SWAPFILE 已关闭。"
    else
        info "保持当前 Swap 状态，不做修改。"
    fi
    exit 0
fi

while true; do
    read -rp "请选择单位 GB 或 MB（输入 G 或 M）: " UNIT
    UNIT=${UNIT^^}
    [[ "$UNIT" == "G" || "$UNIT" == "M" ]] && break
    error "请输入 G 或 M。"
done

while true; do
    read -rp "请输入想创建的 Swap 大小（单位：$UNIT）: " SIZE
    [[ "$SIZE" =~ ^[1-9][0-9]*$ ]] && break
    error "请输入正整数。"
done

if [[ "$UNIT" == "G" ]]; then
    SIZE_MB=$((SIZE * 1024))
else
    SIZE_MB=$SIZE
fi

AVAILABLE_MB=$(df -Pm / | awk 'NR == 2 {print $4}')
if (( AVAILABLE_MB <= SIZE_MB + 64 )); then
    error "磁盘可用空间不足：可用 ${AVAILABLE_MB}MB，需要至少 $((SIZE_MB + 64))MB。"
    exit 1
fi

FS_TYPE=$(findmnt -no FSTYPE -T / 2>/dev/null || true)
info "根目录文件系统：${FS_TYPE:-未知}"

if [[ "$FS_TYPE" == "overlay" || "$FS_TYPE" == "aufs" || "$FS_TYPE" == "squashfs" ]]; then
    error "当前根目录使用 $FS_TYPE，不能在其中创建 Swap 文件。"
    exit 1
fi

if [[ -e "$SWAPFILE" ]]; then
    warn "$SWAPFILE 已存在但未启用，将重新创建。"
    rm -f "$SWAPFILE"
fi

info "正在创建 ${SIZE_MB}MB 的 Swap 文件，请稍候..."

if [[ "$FS_TYPE" == "btrfs" ]]; then
    touch "$SWAPFILE"
    if ! chattr +C "$SWAPFILE" 2>/dev/null; then
        error "无法为 Btrfs Swap 文件关闭 CoW。"
        rm -f "$SWAPFILE"
        exit 1
    fi
    btrfs property set "$SWAPFILE" compression none >/dev/null 2>&1 || true
fi

# 实际写入每个数据块，避免 fallocate 在部分文件系统上产生内核不接受的 Swap 文件。
dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE_MB" status=progress conv=fsync
chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"

info "正在启用 Swap ..."
if ! SWAPON_ERROR=$(swapon "$SWAPFILE" 2>&1); then
    error "启用失败：$SWAPON_ERROR"
    error "文件系统类型：${FS_TYPE:-未知}"
    error "未修改 /etc/fstab。请执行 'dmesg | tail -n 30' 查看内核给出的具体原因。"
    exit 1
fi

if ! grep -Eq "^[[:space:]]*${SWAPFILE//\//\/}[[:space:]]" /etc/fstab; then
    cp -a /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
    printf '%s\n' "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    info "已写入 /etc/fstab，重启后会自动启用。"
else
    info "/etc/fstab 已存在对应条目，跳过写入。"
fi

info "Swap 创建并启用成功："
swapon --show
free -h
