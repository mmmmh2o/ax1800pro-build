#!/usr/bin/env bash
# ============================================================
# 升级前勘察 —— 在【当前系统】上跑
# 目的: 升级前把不可恢复的信息全部留档
#
# 用法:
#   scp build-ax1800pro/scripts/check-before-flash.sh root@192.168.100.1:/tmp/
#   ssh root@192.168.100.1 'sh /tmp/check-before-flash.sh'
#
# 你现网是 iStoreOS/QWRT R24.5.20 (OpenWrt 19.07 基座 / 内核 4.4.60)
# ============================================================

OUT=/tmp/preupgrade-$(date +%Y%m%d-%H%M).txt
exec > >(tee "$OUT") 2>&1

echo "=========================================="
echo "升级前勘察  $(date)"
echo "结果同时保存到: $OUT"
echo "=========================================="

echo
echo "=== 1. 板级标识 ==="
cat /etc/openwrt_release 2>/dev/null
echo "board_name : $(cat /tmp/sysinfo/board_name 2>/dev/null)"
echo "model      : $(cat /tmp/sysinfo/model 2>/dev/null)"
echo "kernel     : $(uname -r)"

echo
echo "=== 2. 内存（确认 1GB）==="
free -m
echo "--- meminfo ---"
grep -E "MemTotal|MemAvailable" /proc/meminfo
echo "--- 设备树内存节点 ---"
ls /proc/device-tree/memory* 2>/dev/null && \
  for d in /proc/device-tree/memory*; do
    echo -n "$d: "
    od -An -tx1 -N16 "$d/reg" 2>/dev/null | tr -d '\n'
    echo
  done

echo
echo "=== 3. eMMC 分区布局（决定能否对齐上游）==="
cat /proc/partitions
echo "--- GPT 分区名 ---"
which parted >/dev/null 2>&1 && parted -s /dev/mmcblk0 print 2>/dev/null || echo "(无 parted，试 sgdisk)"
which sgdisk >/dev/null 2>&1 && sgdisk -p /dev/mmcblk0 2>/dev/null
echo "--- 关键分区名（上游期待 BOOTCONFIG / HLOS / rootfs）---"
ls -l /dev/mmcblk0p* 2>/dev/null | head -30

echo
echo "=== 4. 当前启动槽位 ==="
cat /proc/cmdline
echo "--- 挂载 ---"
mount | grep -E ' / |/overlay|/rom' | head -5
echo "--- U-Boot 环境里的启动命令 ---"
which fw_printenv >/dev/null 2>&1 && {
    echo "fw_env.config:"; cat /etc/fw_env.config
    echo "--- 全量环境 ---"; fw_printenv 2>/dev/null
} || echo "(未装 uboot-envtools)"

echo
echo "=== 5. MAC 地址（升级后可能变化，务必留档）==="
for d in /sys/class/net/*; do
    n=$(basename "$d")
    case "$n" in
        lo|*.*|docker*|veth*|tun*|tap*|utun*) continue ;;
    esac
    echo "$n: $(cat "$d/address" 2>/dev/null)"
done
echo "--- 特别是 WAN 上手动锁定的 MAC ---"
uci get network.wan.macaddr 2>/dev/null && echo "  ^ network.wan.macaddr (手动设定，必须恢复)"
uci get network.lan.macaddr 2>/dev/null

echo
echo "=== 6. 无线校准数据（刷错会没 WIFI）==="
ls -l /lib/firmware/IPQ6018/ 2>/dev/null
find /lib/firmware -iname "*jdcloud*" -o -iname "*JDC*" 2>/dev/null
echo "--- 当前无线设备 ---"
iwinfo 2>/dev/null | head -20
for d in /sys/class/net/*/wireless; do
    n=$(basename $(dirname "$d"))
    echo "$n: $(cat /sys/class/net/$n/address 2>/dev/null)"
done

echo
echo "=== 7. 系统规模与已装包 ==="
echo "已装包数: $(opkg list-installed 2>/dev/null | wc -l)"
echo "--- 已装包清单 ---"
opkg list-installed 2>/dev/null

echo
echo "=== 8. eMMC 可用空间（决定是否需要整机备份）==="
df -h / /overlay /mnt/mmcblk0p27 2>/dev/null

echo
echo "=== 9. 关键配置快照 ==="
for s in network wireless firewall dhcp samba openclash shadowsocksr ua3f; do
    echo "--- $s ---"
    uci show "$s" 2>/dev/null | head -40
done

echo
echo "=========================================="
echo "完成。请把 $OUT 完整下载保存。"
echo "下一步: 在电脑上执行"
echo "  scp root@192.168.100.1:$OUT ./"
echo "=========================================="
