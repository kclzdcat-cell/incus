#!/usr/bin/env bash
# =============================================================================
#  Incus 漏洞一键检测 / 升级
#  重点：CVE-2026-112816（CVSS 10.0，证书链认证绕过，可冒充面板）→ 7.6 修复
#  用法：sudo bash incus-cve-check.sh
#  数据截至 2026-11-02，新版本发布后改下面三个变量即可
# =============================================================================
set -uo pipefail

FIX_VER="7.6.0"        # CVE-2026-112816 修复版本
LTS70_LATEST="7.0.2"   # 7.0 LTS 最新
LTS60_LATEST="6.0.7"   # 6.0 LTS 最新

# ---------------- 样式 ----------------
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; D=$'\e[2m'; W=$'\e[1m'; N=$'\e[0m'
else R=; G=; Y=; D=; W=; N=; fi
line() { echo "${D}────────────────────────────────────────────────────${N}"; }
row()  { printf "  %-10s %s\n" "$1" "$2"; }   # 两列对齐

# 版本号补齐成三段再比较："7.6" → "7.6.0"，避免 7.6 被误判为 < 7.6.0
norm() { local a b c; IFS=. read -r a b c <<<"$1"; echo "${a:-0}.${b:-0}.${c:-0}"; }
ver_lt() {
  local x y; x="$(norm "$1")"; y="$(norm "$2")"
  [ "$x" != "$y" ] && [ "$(printf '%s\n%s\n' "$x" "$y" | sort -V | head -n1)" = "$x" ]
}

ask() {
  local a=""
  printf '  %s' "$1" >&2
  { read -r a </dev/tty; } 2>/dev/null || read -r a || true
  echo "$a"
}

get_server_ver() {
  incus version 2>/dev/null | awk -F': *' '/[Ss]erver version/{print $2}' | tr -d '[:space:]'
}

# =============================================================================
#  收集信息
# =============================================================================
command -v incus >/dev/null 2>&1 || { echo "${R}未找到 incus 命令，本机没有安装 Incus。${N}"; exit 1; }

SERVER_VER="$(get_server_ver)"
if [ -z "$SERVER_VER" ] || [ "$SERVER_VER" = "unreachable" ]; then
  SERVER_VER="$(incusd --version 2>/dev/null | tr -d '[:space:]')"
fi
VER="$(echo "$SERVER_VER" | grep -oE '^[0-9]+(\.[0-9]+){1,2}')"
[ -z "$VER" ] && { echo "${R}无法读取 Incus 版本（incus 守护进程是否在运行？）${N}"; exit 1; }
MAJMIN="$(norm "$VER" | cut -d. -f1,2)"

# 安装来源
SOURCE="unknown"; ZFILE=""; CHANNEL=""; PKG_VER=""
if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' incus 2>/dev/null | grep -q "install ok installed"; then
  PKG_VER="$(dpkg-query -W -f='${Version}' incus)"
  ZFILE="$(grep -rlsE 'pkgs\.zabbly\.com/incus' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | head -n1)"
  if [ -n "$ZFILE" ]; then
    SOURCE="zabbly"
    CHANNEL="$(grep -ohE 'pkgs\.zabbly\.com/incus/[A-Za-z0-9._-]+' "$ZFILE" | head -n1 | awk -F/ '{print $3}')"
  else
    SOURCE="distro"
  fi
elif command -v rpm >/dev/null 2>&1 && rpm -q incus >/dev/null 2>&1; then SOURCE="rpm"
elif command -v pacman >/dev/null 2>&1 && pacman -Q incus >/dev/null 2>&1; then SOURCE="pacman"
fi
case "$SOURCE" in
  zabbly) SRC_TXT="Zabbly 官方源 · ${CHANNEL} 通道" ;;
  distro) SRC_TXT="发行版仓库（$PKG_VER）" ;;
  rpm|pacman) SRC_TXT="$SOURCE 包" ;;
  *) SRC_TXT="未识别（源码编译或其它方式）" ;;
esac

# 漏洞判定
VULN=0; ver_lt "$VER" "$FIX_VER" && VULN=1
BRANCH_NOTE=""
case "$MAJMIN" in
  7.0) BRANCH_NOTE="7.0 LTS"; ver_lt "$VER" "$LTS70_LATEST" && BRANCH_NOTE="$BRANCH_NOTE，且低于 $LTS70_LATEST，还缺 26 个其它 CVE 修复" ;;
  6.0) BRANCH_NOTE="6.0 LTS"; ver_lt "$VER" "$LTS60_LATEST" && BRANCH_NOTE="$BRANCH_NOTE，且低于 $LTS60_LATEST，还缺 44 个其它 CVE 修复" ;;
esac
DISTRO_WARN=0
[ "$SOURCE" = "distro" ] && echo "$PKG_VER" | grep -qE '\+deb|ubuntu|~' && DISTRO_WARN=1

# 网络暴露
ADDR="$(incus config get core.https_address 2>/dev/null || true)"
CADDR="$(incus config get cluster.https_address 2>/dev/null || true)"
EXPOSED=0; ALL_IF=0; PORT=""
for v in "$ADDR" "$CADDR"; do
  [ -z "$v" ] && continue
  EXPOSED=1
  p="$(echo "$v" | grep -oE '[0-9]+$')"; PORT="${p:-8443}"
  h="${v%:*}"
  [[ -z "$h" || "$h" =~ ^(0\.0\.0\.0|\[::\]|::)$ ]] && ALL_IF=1
done
FW=""
if [ "$EXPOSED" = 1 ]; then
  command -v iptables-save >/dev/null 2>&1 && iptables-save 2>/dev/null | grep -qE -- "--dport $PORT( |$)" && FW="iptables"
  command -v nft >/dev/null 2>&1 && nft list ruleset 2>/dev/null | grep -qE "dport $PORT\b" && FW="${FW:+$FW/}nftables"
  command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qE "^$PORT(/tcp)? " && FW="${FW:+$FW/}ufw"
fi

# 证书 / 实例
TRUST="$(incus config trust list -f csv 2>/dev/null | awk -F, 'NF{print $1"("$2")"}' | paste -sd' ' -)"
NTRUST="$(incus config trust list -f csv 2>/dev/null | grep -c . || true)"
NINST="$(incus list --all-projects -f csv -c n 2>/dev/null | grep -c . || true)"

# =============================================================================
#  报告
# =============================================================================
echo
echo "${W}  Incus 漏洞检测${N}   ${D}（数据截至 2026-11-02）${N}"
line
row "版本"   "${W}$SERVER_VER${N}   ${D}$SRC_TXT${N}"

if [ "$VULN" = 0 ]; then
  row "漏洞"   "${G}✓ 已修复${N} CVE-2026-112816（需 ≥ 7.6，你是 $VER）"
else
  row "漏洞"   "${R}✗ 存在${N} CVE-2026-112816（CVSS 10.0，需 ≥ 7.6，你是 $VER）"
  [ -n "$BRANCH_NOTE" ] && row "" "${Y}$BRANCH_NOTE；官方未发布 LTS 补丁${N}"
fi
[ "$DISTRO_WARN" = 1 ] && row "" "${Y}发行版包可能打过补丁，请以发行版安全公告为准${N}"

if [ "$EXPOSED" = 0 ]; then
  row "网络" "${G}✓ API 未对外开放${N}（只走本地 socket）"
elif [ -n "$FW" ]; then
  row "网络" "${Y}! 端口 $PORT 对外开放，防火墙（$FW）有规则${N}，请确认只放行面板 IP"
elif [ "$ALL_IF" = 1 ]; then
  row "网络" "${Y}! 端口 $PORT 对所有 IP 开放，本机未发现防火墙规则${N}"
else
  row "网络" "${Y}! 端口 $PORT 对外开放（$ADDR $CADDR）${N}"
fi

row "证书" "${NTRUST:-0} 个受信任：${TRUST:-无}"
row "实例" "${NINST:-?} 个（所有项目）"
line

# ---------------- 结论 ----------------
show_fw_tip() {
  echo "  只允许面板访问 $PORT（把 PANEL_IP 换成面板服务器 IP）："
  echo "    ${D}iptables  -I INPUT 1 -p tcp --dport $PORT -s PANEL_IP -j ACCEPT${N}"
  echo "    ${D}iptables  -I INPUT 2 -p tcp --dport $PORT -j DROP${N}"
  echo "    ${D}ip6tables -I INPUT 1 -p tcp --dport $PORT -j DROP${N}"
  echo "  ${D}（用云服务器的话，在安全组里限制更简单）${N}"
}

if [ "$VULN" = 0 ]; then
  echo "  ${G}${W}✓ 结论：安全，已修复 CVE-2026-112816，无需升级。${N}"
  if [ "$EXPOSED" = 1 ] && [ -z "$FW" ]; then
    echo
    echo "  ${Y}建议（非必须）：${N}8443 目前任何人都能连，建议加一道防火墙作为额外保护。"
    show_fw_tip
  fi
  echo
  echo "  ${D}另外请核对上面的证书列表，确认都是你自己添加的。${N}"
  exit 0
fi

if [ "$EXPOSED" = 1 ]; then
  echo "  ${R}${W}✗ 结论：高危！版本有漏洞且 API 对外开放，可被远程冒充面板。${N}"
  echo
  echo "  ${W}第一步，先止血：${N}"
  show_fw_tip
else
  echo "  ${Y}${W}! 结论：版本有漏洞，但 API 未对外开放，暂时无法被远程利用。建议升级。${N}"
fi
echo

# ---------------- 升级选项 ----------------
case "$SOURCE" in
  rpm)     echo "  升级：sudo dnf upgrade incus，然后重新运行本脚本。"; exit 2 ;;
  pacman)  echo "  升级：sudo pacman -Syu incus，然后重新运行本脚本。"; exit 2 ;;
  unknown) echo "  请手动升级到 7.6 或更高，然后重新运行本脚本。"; exit 2 ;;
esac
[ "$(id -u)" -ne 0 ] && { echo "  升级需要 root，请用 sudo 重新运行。"; exit 2; }

TO_STABLE=0
echo "  ${W}第二步，升级：${N}"
if [ "$SOURCE" = "zabbly" ] && [[ "$CHANNEL" == lts-* ]]; then
  echo "    1) 切换到 stable 并升级到 7.6+   ${G}← 推荐，能修复此漏洞${N}"
  echo "       ${D}注意：之后不能退回 LTS，需要每月跟着升级${N}"
  echo "    2) 留在 $CHANNEL，升级到最新 LTS   ${D}（修其它漏洞，但此漏洞仍在）${N}"
  echo "    0) 不升级"
  case "$(ask "请选择 [1/2/0]: ")" in
    1) TO_STABLE=1 ;;
    2) ;;
    *) echo "  已取消，未做任何更改。"; exit 2 ;;
  esac
else
  [ "$SOURCE" = "distro" ] && echo "    ${D}（发行版仓库能升到哪个版本，取决于发行版是否已推送更新）${N}"
  echo "    1) 立即升级"
  echo "    0) 不升级"
  [ "$(ask "请选择 [1/0]: ")" = "1" ] || { echo "  已取消，未做任何更改。"; exit 2; }
fi

# =============================================================================
#  执行升级
# =============================================================================
echo
echo "${W}  正在升级…${N}"
line
STAMP="$(date +%Y%m%d%H%M%S)"
if [ "$TO_STABLE" = 1 ]; then
  cp -a "$ZFILE" "$ZFILE.bak.$STAMP"
  sed -i -E "s#(pkgs\.zabbly\.com/incus/)${CHANNEL}#\1stable#g" "$ZFILE"
  echo "  ✓ 软件源已切换到 stable ${D}（备份：$ZFILE.bak.$STAMP）${N}"
fi
BK="/root/incus-db-backup-$STAMP.tar.gz"
if [ -d /var/lib/incus/database ] && tar -czf "$BK" -C /var/lib/incus database 2>/dev/null; then
  echo "  ✓ 数据库已备份 ${D}（$BK）${N}"
fi
echo "  ${D}升级中 API 会短暂断开，运行中的容器一般不受影响${N}"

PKGS="$(dpkg-query -W -f='${binary:Package} ${Status}\n' 'incus*' 2>/dev/null | awk '/install ok installed/{print $1}' | tr '\n' ' ')"
apt-get update -q >/dev/null 2>&1 || { echo "  ${R}✗ apt-get update 失败，请检查网络/软件源${N}"; exit 1; }
# shellcheck disable=SC2086
if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -q --only-upgrade $PKGS; then
  echo "  ${R}✗ apt 升级失败，请查看上面的输出${N}"; exit 1
fi
incus admin waitready --timeout=120 >/dev/null 2>&1 || sleep 5

NEW_RAW="$(get_server_ver)"
NEW="$(echo "$NEW_RAW" | grep -oE '^[0-9]+(\.[0-9]+){1,2}')"
line

if [ -z "$NEW" ]; then
  echo "  ${R}${W}✗ 升级后 incus 没有正常启动！${N}"
  echo "  排查：systemctl status incus ; journalctl -u incus -n 100"
  [ -f "$BK" ] && echo "  数据库备份：$BK"
  exit 1
fi

row "升级前" "$SERVER_VER"
row "升级后" "${W}$NEW_RAW${N}"
echo
if ! ver_lt "$NEW" "$FIX_VER"; then
  echo "  ${G}${W}✓ 升级成功！漏洞已修复。${N}"
  echo
  echo "  接下来："
  echo "   · 打开面板试一下：能连上、能开关机就没问题"
  echo "   · 7.6 起虚拟机默认不走网卡 PXE 启动，面板开 VM 时留意一下"
  echo "   · stable 通道每月出新版，记得定期 apt upgrade"
  [ "$EXPOSED" = 1 ] && [ -z "$FW" ] && echo "   · 建议给 $PORT 端口加防火墙，只放行面板 IP"
  exit 0
elif [ "$(norm "$NEW")" != "$(norm "$VER")" ]; then
  echo "  ${Y}${W}! 已升级到 $NEW，但这个漏洞要 7.6 才修复，目前仍存在。${N}"
  echo "  请保持防火墙只放行面板 IP，或重新运行本脚本选择切换到 stable。"
  exit 2
else
  echo "  ${Y}${W}! 版本没变：软件源里暂时没有更新的版本。${N}"
  echo "  请先做好防火墙限制；发行版仓库没更新时，可改用 Zabbly 源：https://github.com/zabbly/incus"
  exit 2
fi
