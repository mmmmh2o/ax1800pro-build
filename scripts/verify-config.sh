#!/usr/bin/env bash
# 校验 seed.config 的符号是否真的落进了 .config
# 背景: kconfig 对未知符号是静默丢弃的，写错不会报错，
#       只会在编出来的固件里少了功能 —— 必须显式核对。
#
# 两个预置的差异由 .config 内容自动推断，不需要传 PRESET：
#   lean       ath11k-firmware-ipq6018        nss-firmware-ipq6018
#   vikingyfy  ath11k-firmware-ipq6018-ddwrt  nss-firmware
set -uo pipefail

RESOLVED="${1:?用法: verify-config.sh <resolved .config> [seed.config]}"
SEED="${2:-}"

[ -f "$RESOLVED" ] || { echo "找不到 $RESOLVED"; exit 1; }

fail=0

check_eq() {
    local sym="$1" desc="$2"
    if grep -qE "^${sym}=y$" "$RESOLVED"; then
        echo "  ok   ${desc}"
    else
        echo "::error::配置未生效: ${sym}=y （${desc}）—— 符号名可能写错或依赖未满足"
        fail=1
    fi
}

# 二选一的符号组：任一命中即可
check_one_of() {
    local desc="$1"; shift
    for sym in "$@"; do
        if grep -qE "^${sym}=y$" "$RESOLVED"; then
            echo "  ok   ${desc}  (${sym})"
            return 0
        fi
    done
    echo "::error::配置未生效: ${desc} —— 以下符号一个都没有: $*"
    fail=1
}

echo "=== 设备与镜像（缺一不可）==="
check_eq CONFIG_TARGET_qualcommax_ipq60xx "ipq60xx 子目标"
check_eq CONFIG_TARGET_qualcommax_ipq60xx_DEVICE_jdcloud_re-ss-01 "AX1800 Pro 设备"
check_eq CONFIG_TARGET_ROOTFS_INITRAMFS "initramfs 镜像（首次刷机必需）"

echo "=== 无线（缺了会没 WiFi）==="
check_eq CONFIG_PACKAGE_ipq-wifi-jdcloud_re-ss-01 "板级 BDF 校准文件"
check_one_of "IPQ6018 ath11k 固件" \
    CONFIG_PACKAGE_ath11k-firmware-ipq6018 \
    CONFIG_PACKAGE_ath11k-firmware-ipq6018-ddwrt
check_eq CONFIG_PACKAGE_kmod-ath11k-ahb "ath11k AHB 驱动"

echo "=== NSS 硬件加速 ==="
check_eq CONFIG_PACKAGE_kmod-qca-nss-dp "NSS 数据面"
check_eq CONFIG_PACKAGE_kmod-qca-nss-drv "NSS 驱动"
check_eq CONFIG_PACKAGE_kmod-qca-nss-ecm "ECM 连接管理"
check_eq CONFIG_PACKAGE_kmod-qca-ssdk "SSDK 交换芯片"
check_one_of "NSS 固件" \
    CONFIG_PACKAGE_nss-firmware-ipq6018 \
    CONFIG_PACKAGE_nss-firmware

echo "=== USB 手机共享（核心需求）==="
check_eq CONFIG_PACKAGE_kmod-usb-net-rndis "RNDIS 驱动"
check_eq CONFIG_PACKAGE_kmod-usb-net-cdc-ether "CDC Ethernet 驱动"
check_eq CONFIG_PACKAGE_kmod-usb-net-cdc-ncm "NCM 驱动"

echo "=== Lua 兼容层（截图里多数插件依赖）==="
check_eq CONFIG_PACKAGE_luci-compat "luci-compat"

# 全量对照 seed: 列出所有没生效的符号
if [ -n "$SEED" ] && [ -f "$SEED" ]; then
    echo "=== 全量对照 seed.config ==="
    missing=0
    while IFS= read -r line; do
        case "$line" in
            CONFIG_*=y)
                sym="${line%=y}"
                if ! grep -qE "^${sym}=y$" "$RESOLVED"; then
                    echo "::warning::seed 中的 ${sym}=y 未生效"
                    missing=$((missing+1))
                fi
                ;;
        esac
    done < "$SEED"
    echo "未生效符号数: ${missing}"
fi

if [ "$fail" -ne 0 ]; then
    echo ""
    echo "关键配置校验失败。常见原因："
    echo "  1. 符号名拼错（本分支 ath11k 固件包名带 -ddwrt 后缀）"
    echo "  2. 依赖未满足（wpad-openssl 与 wpad-basic 互斥）"
    echo "  3. 包在这套源码树里不存在（第三方 feed 没挂上）"
    exit 1
fi

echo ""
echo "关键配置校验通过。"
