# AX1800 Pro (RE-SS-01) 自编译方案

面向：京东云无线宝 AX1800 Pro，当前跑 iStoreOS/QWRT R24.5.20
目标：在 GitHub Actions 上云端编出符合自己使用习惯的固件
版本：v2 —— 双预置（Lean / VIKINGYFY），手动触发时选一个即可

---

## 0. 一句话结论

**你的机器可以自编译，但必须接受三个前提：**

1. **不能编 iStoreOS 官方源码** —— iStoreOS 的 `qualcommax/ipq60xx`
   目标里根本没有这台机器（24.10 / 25.12 分支都查过了，一个 jdcloud
   设备都没有）。你现在的 QWRT 是厂商闭源分支，源码不公开，所以
   "重编一个一模一样的 iStoreOS" 做不到。

2. **两条开源路线都可行**，都已逐符号核验：
   - **Lean LEDE**（默认预置）：opkg + Lua LuCI + NSS，和你现在的习惯最接近
   - **VIKINGYFY/immortalwrt**：内核 6.18 + NSS 全栈 + 1GB 内存无限制，但要换 apk

3. **USB 手机共享不需要再打补丁** —— 你的 Sony 手机（VID 0x0fce）走
   标准 Android RNDIS（EF/04/01），内核 5.4+ 的 `rndis_host` 已原生
   匹配这个接口类。老内核 4.4 才需要你手工 patch `.ko`，新内核不用。

---

## 1. 设备确认

| 项 | 值 | 来源 |
|---|---|---|
| 机型 | 京东云 AX1800 Pro | 上游 commit 与源码中的 `DEVICE_MODEL` |
| 设备 ID | `jdcloud_re-ss-01` | 上游 / Lean / VIKINGYFY 的 `ipq60xx.mk` |
| SoC | Qualcomm IPQ6000（IPQ6018 家族）1.2GHz 四核 A53 | 上游 commit 说明 |
| 内存 | **1GB**（你确认过；512MB 是另一个变体） | 你的说明 |
| 闪存 | eMMC 64/128 GB（FORESEE） | 归档里有 `/dev/mmcblk0p*`、`/mnt/mmcblk0p27` |
| 有线 | QCA8075，3×LAN + 1×WAN | `network` 里 eth0-eth2 桥接、eth3 作 WAN |
| 无线 | QCN5022 (2.4G AX 2x2) + QCN5052 (5G AX 2x2) | 上游 commit 说明 |
| 当前系统 | OpenWrt 19.07 基座 / 内核 **4.4.60** | `NOTES.md` 与备份 |
| 包管理 | opkg（aarch64_cortex-a53 + crypto） | `etc/opkg.conf` |

### 1GB 内存的技术结论（重要）

- **内存容量不是 DTS 写死的**。主线内核 `ipq6018.dtsi` 里没有
  `memory@` 节点，容量由 U-Boot 启动时传入 —— 所以 1GB 会被
  自动识别，不需要改 DTS。
- 两个预置对内存布局的处理：
  - **Lean** 的设备 DTS 含 `ipq6018-512m.dtsi`：只是把 WiFi 固件
    保留区（q6_region）从 85MB 缩到 55MB，给 Linux 多让 30MB。
    在 1GB 机器上无害。
  - **VIKINGYFY** 不含该文件，用默认 85MB 布局，对 1GB 更"原厂"。
- 刷完第一件事：`free -m` 确认总内存 ≈ 1000MB 左右。如果只看到
  500MB，说明 U-Boot 传的是 512MB，那就要查 U-Boot 环境了。

---

## 2. 两条路线，怎么选

两套我都逐符号核验过（包名、依赖、撞名检查都过了），都能编出
含你截图全部服务的固件。

| | **预置 A: Lean LEDE** | **预置 B: VIKINGYFY/immortalwrt** |
|---|---|---|
| 仓库 | coolsnowwolf/lede @ master | VIKINGYFY/immortalwrt @ main |
| 支持 RE-SS-01 | ✅（叫 "AX1800 Pro"） | ✅ |
| NSS 硬件加速 | ✅ 4 个基础模块 | ✅ **20+ 个模块**（含 PPPoE/VLAN/GRE/L2TP/tunipip6/VXLAN） |
| 内核 | 6.12（testing 6.18） | **6.18** |
| 包管理 | **opkg**（和现在一致） | apk（要换习惯） |
| LuCI | **Lua 版**（bugs3.lua 直接搬） | Lua+JS 混合（需 luci-compat，已含） |
| 1GB 内存布局 | 512m 缩减版（无害） | 默认完整版 |
| 维护活跃度 | 大社区，ipq60xx NSS 实战里程多 | 590 星，个人维护，更新频繁（2026-10 仍活跃） |
| 插件来源 | Lean 自带 feed + helloworld + kenzok8 | immortalwrt feeds + kenzok8 |
| ath11k 固件 | 官方 `ath11k-firmware-ipq6018` | ddwrt fork（`-ddwrt` 后缀） |
| 风险点 | 内核偏旧；lean 的 NSS 是基础版 | 个人 fork 信任问题；apk 生态较新 |

### 我的建议（考虑过后的）

**默认用 Lean（预置 A），把它当"稳态日常版"：**

1. 你笔记里所有运维命令、备份脚本、`bugs3.lua` 自写页面都是
   opkg + Lua LuCI 语境，Lean 零适配成本。
2. 同类芯片（IPQ60xx/IPQ807x）上 Lean 的 NSS 组合被大量用户跑过，
   踩坑资料多；VIKINGYFY 的 6.18 + NSS 是新组合，出问题没先例可查。
3. 你要的服务在 Lean 生态里全都有一手包，不需要跨源拼凑。

**VIKINGYFY（预置 B）留给"追新"场景：** 等你稳定跑通一版之后，
想试 6.18 内核和完整 NSS offload（比如 PPPoE 硬件卸载），再切换
预置编一版对比。工作流里改一个下拉框就行，不用改任何文件。

### 截图服务 → 包名对照（两套预置都覆盖）

| 你截图里的菜单 | Lean 预置 | VIKINGYFY 预置 |
|---|---|---|
| UA3F | `ua3f`（官方包，无 LuCI 界面） | 同左 |
| ShadowSocksR Plus+ | `luci-app-ssr-plus`（helloworld） | 同左（kz） |
| 易有云文件管理器 | `luci-app-linkease`（kz） | 同左 |
| DDNSTO 远程控制 | `luci-app-ddnsto` + `ddnsto`（kz） | 同左 |
| 网站域名黑白名单配置 | `luci-app-control-webrestriction`（kz） | 同左 |
| 上网时间控制 | `luci-app-timecontrol`（Lean 自带） | kz 拷入 |
| OpenClash | `luci-app-openclash`（Lean 自带） | immortalwrt 自带 |
| 动态 DNS | `luci-app-ddns` | 同左 |
| Multi Stream Daemon | `luci-app-msd_lite` + `msd_lite` 后端 | 同左 |
| MAC白名单测试 | ⚠️ 无开源对应（QWRT 闭源件），用 `luci-app-arpbind`/防火墙规则替代 | 同左 |
| 网络唤醒Plus | `luci-app-wolplus` + `etherwake`（kz） | 同左 |
| UPnP | `luci-app-upnp` | 同左 |
| KMS 服务器 | `luci-app-vlmcsd` | 同左 |
| XUPNP IPTV | `xupnpd` 后端 ✅（**无 LuCI 界面**，所有开源树都没有，原来那个界面是 QWRT 闭源件） | 同左 |
| CPU 性能优化调节 | `luci-app-cpufreq` | 同左 |

工作流会自动判断：feed 里已有的包不重复拷，只补缺口，所以两套
预置共用同一段"挂第三方包"逻辑，不会撞名。

---

## 3. 云端编译（GitHub Actions）

### 3.1 你需要做的事（涉及账号）

我无法替你登录 GitHub，需要你操作：

1. **新建一个仓库**（建议 **private**）：
   例如 `ax1800pro-build`。private 不是必须，但里面会有你的
   网络配置，别公开。
2. **把本目录内容推上去**：
   ```bash
   cd build-ax1800pro
   git init
   git add .
   git commit -m "init"
   git branch -M main
   git remote add origin https://github.com/<你的账号>/ax1800pro-build.git
   git push -u origin main
   ```
3. 仓库 **Settings → Actions → General**，确认
   "Allow all actions and reusable workflows" 已勾选。
4. 进入 **Actions 标签页 → Build AX1800 Pro firmware → Run workflow**，
   **在 preset 下拉框里选 `lean` 或 `vikingyfy`**，点运行。
   - 源码仓库/分支两个输入框留默认即可 —— 预置会自动带出对应的
     仓库和分支；只有你想用别的 fork 时才需要改。

> 如果你要我帮你推仓库，你需要提供一个有 `repo` 权限的
> Personal Access Token，或者本机先 `gh auth login`。
> 这一步会碰到你自己的账号凭据，建议你自己执行。

### 3.2 免费额度够不够

- public 仓库：Actions **完全免费**，不限分钟数。
- private 仓库：免费额度 2000 分钟/月。
- 本方案**首次全量编译约 40–70 分钟**（4 核 runner，含下载）。
  之后有 dl 缓存，约 25–40 分钟。
- 一个月编 3–5 次，private 额度也够用。想更省就把仓库设 public，
  但**先把 `configs/` 里的 Wi-Fi 密码之类清空**。

### 3.3 工作流做了什么

`.github/workflows/build.yml` 的步骤：

| 步骤 | 作用 | 不做会怎样 |
|---|---|---|
| Free disk space | 删掉 runner 预装的 .NET/Android 等 | 编内核时报 `No space left on device` |
| Add swap | 加 4G swap | 并行编译偶发 OOM |
| Clone source | 拉 Lean LEDE | — |
| Fetch extra packages | 只拷 Lean 缺的 4 个包 | 见下方"重名坑" |
| Update feeds | `feeds update -a && install -a` | 包找不到 |
| Apply seed config | 套用预置 seed（按 preset 选择） | — |
| **Verify config symbols** | **核对每个符号是否真的生效** | 见下方"静默丢配置坑" |
| Download | `make download -j8` | 编译中途重复下载、易超时 |
| Compile | `make -j$(nproc)` | — |
| Verify artifacts | 检查 initramfs 和 sysupgrade 都存在 | 刷机时才发现缺文件 |
| Upload | 上传产物 + SHA256 | — |

---

## 4. 我替你踩掉的三个坑

### 坑 1：配置静默丢失（最隐蔽）

kconfig 遇到不存在的符号**不会报错，直接丢弃**。比如你把
`ath11k-firmware-ipq6018` 写成 `ath11k-firmware-ipq6000`，
`make defconfig` 一声不响，编出来的固件没无线驱动。

所以方案里加了 `scripts/verify-config.sh`，逐个核对：
- 设备四要素（target / subtarget / device / initramfs）
- NSS 四个内核模块
- 无线校准包 `ipq-wifi-jdcloud_re-ss-01`
- USB 网络模块
- 以及所选 seed 预置里所有 `=y` 的符号

任何一项没生效，CI 直接失败，不会给你一个残缺固件。

### 坑 2：第三方包重名

我原本想从 `kenzok8/small-package` 拷 `luci-app-openclash`、
`luci-app-msd_lite` 等。核对后发现 **Lean 自带的 luci feed 里已经有
这些同名包**，重复拷会触发 `duplicate package`，或产出两份同名 ipk。

而且 `luci-app-msd_lite` 在 Lean 里**只有 UI、没有后端**（后端
`msd_lite` 在 Lean 的 packages feed 里也没有）。

最终策略：
- `msd_lite`：**只从 kz 拷后端**，UI 用 Lean 自带的
- `luci-app-wolplus`、`ddnsto`、`luci-app-ddnsto`：Lean 没有，从 kz 拷
- 其余全部走 Lean 自带 feed
- 工作流里加了撞名自检，真撞了会直接失败而不是编出怪东西

### 坑 3：编译失败被管道吞掉

`make ... 2>&1 | tail -200` 的退出码是 `tail` 的，永远为 0。
CI 会在编译失败的情况下显示绿色通过。已加 `set -o pipefail`。

---

## 5. 刷机（风险最高的一步）

### 5.1 官方给出的刷机路径

来自上游提交 `qualcommax: ipq60xx: add JDCloud RE-SS-01 support`：

```
1. 下载 initramfs 镜像，重命名为 initramfs.itb，用 TFTP 服务器提供
2. 若 stock 固件版本 >= 4.3.0.r4211，在出现
   "disabled console and autoboot in 2 seconds" 时输入
   jdmt018R 打断 U-Boot
3. 在 U-Boot 控制台执行：
     tftpboot initramfs.itb
     bootm
4. OpenWrt 起来后，用 scp 或 LuCI 上传 sysupgrade.bin 升级
```

**这意味着你需要准备：**
- USB-TTL 串口线（3.3V），接到板子的 UART
- 一台电脑跑 TFTP 服务器（Tftpd64 之类）
- 网线直连

### 5.2 为什么不能直接网页升级

- 你现在是 QWRT（19.07 + 内核 4.4.60），分区布局和上游 OpenWrt 的
  eMMC 布局不一定一致。上游 `sysupgrade` 的逻辑是读
  `0:BOOTCONFIG` 分区第 148 字节判断 A/B 槽位，再写 `0:HLOS` /
  `rootfs`。如果 QWRT 的 GPT 分区名不一样，会写错位置。
- 刷机前**必须**先跑 `scripts/check-before-flash.sh`，把
  `/proc/partitions`、`fw_printenv`、MAC、无线校准数据全部留档。

### 5.3 刷机前必须留档的东西

`scripts/check-before-flash.sh` 会采集：

| 项目 | 为什么要 |
|---|---|
| `/etc/openwrt_release`、`board_name` | 确认机型 |
| `/proc/partitions` + GPT | 判断分区能不能对上 |
| `fw_printenv` 全量 | 刷坏了靠它救回来 |
| 每个网口的 MAC | **刷完 MAC 可能变**，你笔记里 WAN 是手动锁了 `00:e0:08:33:65:FF` 的 |
| 无线校准数据位置 | 刷错可能没 WIFI |
| 已装包清单 | 对照新固件缺什么 |

> ⚠️ 你的 WAN MAC 是**手动设定**的（校园网环境），新固件不会自动
> 继承。刷完第一件事就是恢复这个 MAC，否则可能上不了网。

### 5.4 保留旧系统能回去吗

**不能直接回。** 你的 QWRT R24.5.20 是厂商闭源分支，iStoreOS 官方
固件站没有这台机器的镜像（你笔记里也写了这一点）。所以：

- 刷之前**务必**把整个 eMMC 关键分区备份出来
- 至少备份：`/dev/mmcblk0p12`（U-Boot 环境）、启动分区、
  以及当前 rootfs
- 更稳的做法是先 `dd` 一份完整 eMMC 镜像存到电脑上

---

## 6. 从旧系统迁移配置的注意事项

你现有备份是 `tar.gz`，里面是 `/etc` 全量。**不要直接解压覆盖**：

| 项目 | 旧（19.07） | 新（6.12） | 处理 |
|---|---|---|---|
| 防火墙 | fw3 + iptables | fw4 + nftables | 不要覆盖 `firewall`，重新配规则 |
| 无线 | `qcawificfg80211` + `wifi0/wifi1` | `mac80211` + `radio0/radio1` | 手工重配 |
| 网络接口名 | eth0-eth3 | 可能变 lan1/lan2/lan3/wan | 用 DTS 里的 label |
| OpenClash 配置 | `/etc/openclash` 23MB | 可直接复用 yaml | ✅ 可用，但注意内核版本 |
| UA3F | TPROXY 模式 | 需重新编 aarch64 二进制 | 重新编译 |
| 自写 Lua 页面 | `bugs3.lua` + indexcache | Lean 的 Lua LuCI 兼容 | 需确认 LuCI 版本 API |
| 内核模块 | 你手工 patch 的 `.ko` | **完全不能用** | 从源码编（已加进 seed） |

### 关于你手工 patch 的 USB 模块

工作区里的 `rndis_host.ko` / `cdc_ether.ko` 是**二进制 patch**，
打进的是旧内核 4.4.60 的模块。新内核 6.12 的 vermagic 完全不同，
加载会直接报 `Invalid module format`。

正确做法（已写进两个 seed 预置）：
```
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
```
从源码编译。如果是为了**特定手机型号**（你 `patch_rndis.js` 里在改
USB device ID 表），那需要的是：
1. 先确认手机 VID/PID
2. 在新源码树里给 `usb-net-rndis` 加 patch（`patches/` 目录）
3. 或者用 `usb_modeswitch` 规则做，不改内核

---

## 7. 建议的推进顺序

1. **先在 Actions 上跑通一次编译**，不刷机，确认产物正常
2. 拿到 `initramfs.itb`，**只做 TFTP 启动**（不写入 eMMC），
   在内存系统里验证：无线能不能起来、网口顺序对不对、MAC 是什么
3. 内存系统验证 OK 后，再 `sysupgrade` 写入
4. 写完后恢复 WAN MAC、Wi-Fi 配置、代理链路

这个顺序的好处：第 2 步完全不碰 eMMC，出问题断电重启就回到原系统。

---

## 8. 文件清单

```
build-ax1800pro/
├── .github/workflows/build.yml      # 云端编译工作流（preset 下拉切换两套源码树）
├── configs/seed-lean.config         # 预置 A：Lean LEDE（opkg / Lua LuCI / NSS 基础版）
├── configs/seed-vikingyfy.config    # 预置 B：VIKINGYFY/immortalwrt（apk / 内核6.18 / NSS 全栈）
├── scripts/verify-config.sh         # 配置符号校验（防静默丢包，自动识别预置）
├── scripts/check-before-flash.sh    # 升级前留档脚本（内存/分区/MAC/U-Boot 环境）
├── files/etc/uci-defaults/99-custom-defaults  # 首次开机自动配置
└── README.md                        # 本文档
```

---

## 9. 还没解决的问题（等你那两份资料）

你提到还有两份资料要给我。如果里面有：
- 具体的刷机教程 / 引脚定义 → 我补进第 5 节
- 你想要的插件清单 / 界面截图 → 我补进对应 seed 预置
- 现网完整配置 → 我整理成可复用的 uci-defaults

目前方案里**唯一没有实证验证**的是：QWRT 的 eMMC GPT 分区名是否
与上游 OpenWrt 期待的一致（`0:BOOTCONFIG` / `0:HLOS` / `rootfs`）。
这一点必须等路由器开机、跑 `check-before-flash.sh` 才能确认。
