#!/usr/bin/env bash
# =============================================================================
#  incus-cve-check.sh —— Incus 漏洞版本一键检测 / 升级脚本
#
#  重点检测：CVE-2026-112816 / GHSA-xg75-xf37-cph9（CVSS 10.0）
#            客户端证书链未校验 → 远程认证绕过，可冒充面板/受信任客户端
#            官方修复版本：Incus 7.6.0（2026-10-30）
#  附带检测：7.0.2 LTS / 6.0.7 LTS（2026-10-29）修复的一批 CVE
#
#  用法：
#    sudo bash incus-cve-check.sh
#    → 自动检测；发现漏洞版本会弹出选项询问是否升级
#
#  数据截至 2026-11-02，之后如有新版本/新公告请以官方为准：
#    https://linuxcontainers.org/incus/news/
#    https://github.com/lxc/incus/security/advisories
# =============================================================================
set -uo pipefail

# ---------------- 版本基线（如有新发布，改这里即可） ----------------
FIX_CVE_112816="7.6.0"   # 证书链认证绕过的修复版本
LTS70_LATEST="7.0.2"     # 7.0 LTS 最新（2026-10-29）
LTS60_LATEST="6.0.7"     # 6.0 LTS 最新（2026-10-29）

DO_UPGRADE=0; TO_STABLE=0

# ---------------- 输出样式 ----------------
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[36m'; W=$'\e[1m'; N=$'\e[0m'
else
  R=; G=; Y=; B=; W=; N=
fi
ok()   { echo "  ${G}[✓]${N} $*"; }
warn() { echo "  ${Y}[!]${N} $*"; }
bad()  { echo "  ${R}[✗]${N} $*"; }
info() { echo "  ${B}[i]${N} $*"; }
hdr()  { echo; echo "${W}== $* ==${N}"; }

# a < b ?（纯版本号比较）
ver_lt() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -n1)" = "$1" ]; }
ver_ge() { ! ver_lt "$1" "$2"; }

# 从终端读输入（兼容 curl ... | bash 的方式运行）
ask() {
  local a=""
  printf '  %s' "$1" >&2
  { read -r a </dev/tty; } 2>/dev/null || read -r a || true
  echo "$a"
}

RISK=0   # 0=安全 1=有中低风险 2=高危

# =============================================================================
hdr "1. 基本信息"
# =============================================================================
if ! command -v incus >/dev/null 2>&1; then
  bad "未找到 incus 命令，本机可能没有安装 Incus。"; exit 1
fi
[ "$(id -u)" -ne 0 ] && warn "建议用 root / sudo 运行，否则部分检查（防火墙、日志、升级）可能失败。"

VER_OUT="$(incus version 2>/dev/null || true)"
CLIENT_VER="$(echo "$VER_OUT" | awk -F': *' '/[Cc]lient version/{print $2}' | tr -d '[:space:]')"
SERVER_VER="$(echo "$VER_OUT" | awk -F': *' '/[Ss]erver version/{print $2}' | tr -d '[:space:]')"

if [ -z "$SERVER_VER" ] || [ "$SERVER_VER" = "unreachable" ]; then
  # 守护进程连不上时退回 incusd 本身的版本
  if command -v incusd >/dev/null 2>&1; then
    SERVER_VER="$(incusd --version 2>/dev/null | tr -d '[:space:]')"
  fi
  [ -z "$SERVER_VER" ] && SERVER_VER="$CLIENT_VER"
  warn "无法连接 incus 守护进程，以下用本地二进制版本 ${SERVER_VER:-未知} 判断。"
fi
# 只保留数字部分，例如 "7.0.2" / "6.20"
SERVER_NUM="$(echo "$SERVER_VER" | grep -oE '^[0-9]+(\.[0-9]+){1,2}')"
[ -z "$SERVER_NUM" ] && { bad "无法解析版本号：'$SERVER_VER'"; exit 1; }

info "客户端版本：${CLIENT_VER:-未知}"
info "服务端版本：${W}${SERVER_VER}${N}"

# ---- 安装来源 ----
SOURCE="unknown"; ZABBLY_FILE=""; ZABBLY_CHANNEL=""; PKG_VER=""
if command -v dpkg-query >/dev/null 2>&1 && dpkg-query -W -f='${Status}' incus 2>/dev/null | grep -q "install ok installed"; then
  PKG_VER="$(dpkg-query -W -f='${Version}' incus)"
  ZABBLY_FILE="$(grep -rlsE 'pkgs\.zabbly\.com/incus' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | head -n1)"
  if [ -n "$ZABBLY_FILE" ]; then
    SOURCE="zabbly"
    ZABBLY_CHANNEL="$(grep -ohE 'pkgs\.zabbly\.com/incus/[A-Za-z0-9._-]+' "$ZABBLY_FILE" | head -n1 | awk -F/ '{print $3}')"
  else
    SOURCE="distro-deb"
  fi
elif command -v rpm >/dev/null 2>&1 && rpm -q incus >/dev/null 2>&1; then
  SOURCE="rpm"; PKG_VER="$(rpm -q --qf '%{VERSION}-%{RELEASE}' incus)"
elif command -v pacman >/dev/null 2>&1 && pacman -Q incus >/dev/null 2>&1; then
  SOURCE="pacman"; PKG_VER="$(pacman -Q incus | awk '{print $2}')"
fi

case "$SOURCE" in
  zabbly)     info "安装来源：Zabbly 官方源（通道：${W}${ZABBLY_CHANNEL:-未知}${N}，包版本 $PKG_VER）" ;;
  distro-deb) info "安装来源：发行版仓库 deb 包（$PKG_VER）" ;;
  rpm|pacman) info "安装来源：$SOURCE 包（$PKG_VER）" ;;
  *)          info "安装来源：未识别（可能是源码编译 / 其它方式）" ;;
esac

# 发行版包会 backport 补丁，纯看上游版本号不准
BACKPORT=0
if [ "$SOURCE" = "distro-deb" ] && echo "$PKG_VER" | grep -qE '\+deb|ubuntu|~'; then
  BACKPORT=1
fi

# =============================================================================
hdr "2. 漏洞版本判定"
# =============================================================================
MAJMIN="$(echo "$SERVER_NUM" | cut -d. -f1,2)"
TARGET=""

if ver_ge "$SERVER_NUM" "$FIX_CVE_112816"; then
  ok "CVE-2026-112816（证书链认证绕过，CVSS 10.0）：${G}已修复${N}（≥ $FIX_CVE_112816）"
  ok "7.6.0 同批修复的另外 17 个安全问题也已包含"
else
  RISK=2
  bad "CVE-2026-112816（证书链认证绕过，CVSS 10.0）：${R}受影响${N}（< $FIX_CVE_112816）"
  echo "      攻击者可用受信任证书（面板证书/服务器证书）的公钥冒充其身份，无需私钥。"
  TARGET="$FIX_CVE_112816"

  case "$MAJMIN" in
    7.0)
      warn "你在 7.0 LTS 分支。官方公告目前只列 7.6.0 为该漏洞修复版本，未列出 LTS 补丁。"
      if ver_lt "$SERVER_NUM" "$LTS70_LATEST"; then
        bad "另外还低于 $LTS70_LATEST LTS，缺少其中修复的 26 个 CVE（含 14 个 critical）。"
      else
        ok "已是 $LTS70_LATEST LTS，包含该批 26 个 CVE 修复。"
      fi
      ;;
    6.0)
      warn "你在 6.0 LTS 分支（已进入仅安全维护阶段）。官方公告未列出该漏洞的 LTS 补丁。"
      if ver_lt "$SERVER_NUM" "$LTS60_LATEST"; then
        bad "另外还低于 $LTS60_LATEST LTS，缺少其中修复的 44 个 CVE（含 18 个 critical）。"
      else
        ok "已是 $LTS60_LATEST LTS，包含该批 44 个 CVE 修复。"
      fi
      ;;
    *)
      bad "你在月度版本分支（$SERVER_NUM），该分支只支持到下个版本发布，需升级到 ≥ $FIX_CVE_112816。"
      ;;
  esac
fi

if [ "$BACKPORT" = 1 ]; then
  warn "发行版包（$PKG_VER）可能已 backport 部分补丁，上游版本号仅供参考。"
  warn "请到 https://security-tracker.debian.org/tracker/source-package/incus 或对应发行版安全追踪页确认。"
  warn "在发行版明确标注已修复 GHSA-xg75-xf37-cph9 之前，请按「受影响」处理。"
fi

# =============================================================================
hdr "3. 网络暴露检查"
# =============================================================================
EXPOSED=0
HTTPS_ADDR="$(incus config get core.https_address 2>/dev/null || true)"
CLUSTER_ADDR="$(incus config get cluster.https_address 2>/dev/null || true)"
PORTS=""

for pair in "core.https_address=$HTTPS_ADDR" "cluster.https_address=$CLUSTER_ADDR"; do
  key="${pair%%=*}"; val="${pair#*=}"
  if [ -z "$val" ]; then
    ok "$key 未设置"
    continue
  fi
  EXPOSED=1
  port="$(echo "$val" | grep -oE '[0-9]+$')"; [ -z "$port" ] && port=8443
  PORTS="$PORTS $port"
  host="${val%:*}"
  if [ -z "$host" ] || [[ "$host" =~ ^(0\.0\.0\.0|\[::\]|::)$ ]] || [ "$val" = ":$port" ]; then
    bad "$key = ${W}$val${N} → 监听所有网卡（端口 $port）"
  else
    warn "$key = ${W}$val${N} → 监听 $host:$port"
  fi
done
PORTS="$(echo "$PORTS" | tr ' ' '\n' | sort -u | grep -v '^$' | tr '\n' ' ')"

if command -v ss >/dev/null 2>&1 && [ -n "$PORTS" ]; then
  for p in $PORTS; do
    l="$(ss -ltnH "sport = :$p" 2>/dev/null | awk '{print $4}' | tr '\n' ' ')"
    [ -n "$l" ] && info "实际监听（端口 $p）：$l"
  done
fi

# 防火墙粗略检查（只是提示，不能代替人工确认）
if [ "$EXPOSED" = 1 ]; then
  for p in $PORTS; do
    FW_HIT=""
    command -v iptables-save >/dev/null 2>&1 && iptables-save 2>/dev/null | grep -qE -- "--dport $p( |$)" && FW_HIT="iptables"
    command -v nft >/dev/null 2>&1 && nft list ruleset 2>/dev/null | grep -qE "dport $p( |$|\b)" && FW_HIT="${FW_HIT:+$FW_HIT,}nftables"
    command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -qE "^$p(/tcp)? " && FW_HIT="${FW_HIT:+$FW_HIT,}ufw"
    if [ -n "$FW_HIT" ]; then
      info "端口 $p 在本机防火墙（$FW_HIT）中有规则，请确认是「只允许面板 IP」而不是全放行。"
    else
      warn "本机防火墙中没找到针对端口 $p 的规则（云安全组无法从本机检测，请自行确认）。"
    fi
  done
fi

if [ "$EXPOSED" = 1 ] && [ "$RISK" = 2 ]; then
  echo
  echo "  ${R}${W}⚠ 高危：版本受影响 + API 对网络开放 = 可被远程认证绕过。${N}"
  echo "  ${W}立即止血（把 PANEL_IP 换成面板出口 IP）：${N}"
  for p in ${PORTS:-8443}; do
    echo "    iptables  -I INPUT 1 -p tcp --dport $p -s PANEL_IP -j ACCEPT"
    echo "    iptables  -I INPUT 2 -p tcp --dport $p -j DROP"
    echo "    ip6tables -I INPUT 1 -p tcp --dport $p -j DROP"
  done
  echo "  （这只是临时缓解，官方说明没有配置层面的规避方法，仍需升级）"
elif [ "$EXPOSED" = 0 ] && [ "$RISK" = 2 ]; then
  info "API 未对网络开放，CVE-2026-112816 无法被远程利用，但仍建议升级。"
fi

# =============================================================================
hdr "4. 快速入侵排查（只读）"
# =============================================================================
TRUST="$(incus config trust list -f csv 2>/dev/null || true)"
if [ -n "$TRUST" ]; then
  info "受信任证书共 $(echo "$TRUST" | grep -c .) 个（确认每一个你都认识）："
  echo "$TRUST" | awk -F, '{printf "      - %s | %s | %s\n", $1, $2, $NF}'
else
  info "无法读取信任列表或列表为空。"
fi
PROJECTS="$(incus project list -f csv -c n 2>/dev/null | sed 's/ (current)//' | tr '\n' ' ')"
[ -n "$PROJECTS" ] && info "项目：$PROJECTS（有陌生项目要警惕）"
NINST="$(incus list --all-projects -f csv -c n 2>/dev/null | grep -c . || true)"
info "实例总数（所有项目）：${NINST:-?}，用 'incus list --all-projects' 核对是否有陌生实例。"
echo "  注：官方未公布入侵特征（IOC），信任列表没变化不代表没被冒充过。"

# =============================================================================
hdr "5. 结论与建议"
# =============================================================================
if [ "$RISK" = 0 ]; then
  echo "  ${G}${W}✓ 当前版本 $SERVER_VER 已包含 CVE-2026-112816 修复。${N}"
  [ "$EXPOSED" = 1 ] && echo "  建议仍保持 8443 只对面板 IP 开放，作为纵深防御。"
  exit 0
fi

echo "  建议升级到：${W}Incus $TARGET 或更高${N}"

# ---- 非 deb 安装：只能给出手动命令 ----
case "$SOURCE" in
  rpm)     echo "  请执行：sudo dnf upgrade incus（或对应命令），然后重新运行本脚本确认。"; exit 2 ;;
  pacman)  echo "  请执行：sudo pacman -Syu incus，然后重新运行本脚本确认。"; exit 2 ;;
  unknown) echo "  未识别安装方式，请手动升级到 $TARGET+（源码：git checkout v$TARGET 重新编译），再运行本脚本确认。"; exit 2 ;;
esac

if [ "$(id -u)" -ne 0 ]; then
  bad "升级需要 root，请用 sudo 重新运行本脚本。"; exit 2
fi

# ---- 选项菜单 ----
echo
echo "  ${W}请选择：${N}"
if [ "$SOURCE" = "zabbly" ] && [[ "$ZABBLY_CHANNEL" == lts-* ]]; then
  echo "    1) 切换到 stable 通道并升级到 7.6.0+（${G}修复 CVSS 10.0 漏洞，推荐${N}；${Y}之后无法回退到 LTS，需每月跟进升级${N}）"
  echo "    2) 留在 ${ZABBLY_CHANNEL}，升级到该 LTS 最新版（修复其它 CVE，${R}但 CVSS 10.0 漏洞仍未修复${N}）"
  echo "    0) 不升级，退出"
  case "$(ask "输入选项 [1/2/0]: ")" in
    1) TO_STABLE=1; DO_UPGRADE=1 ;;
    2) DO_UPGRADE=1 ;;
    *) echo "  未升级，已退出。请务必先用上面的防火墙命令止血。"; exit 2 ;;
  esac
else
  if [ "$SOURCE" = "distro-deb" ]; then
    echo "  （你用的是发行版仓库包，能升到的版本取决于发行版是否已发布安全更新）"
  fi
  echo "    1) 立即升级"
  echo "    0) 不升级，退出"
  case "$(ask "输入选项 [1/0]: ")" in
    1) DO_UPGRADE=1 ;;
    *) echo "  未升级，已退出。请务必先用上面的防火墙命令止血。"; exit 2 ;;
  esac
fi

# =============================================================================
hdr "6. 执行升级"
# =============================================================================
if [ "$TO_STABLE" = 1 ]; then
  cp -a "$ZABBLY_FILE" "$ZABBLY_FILE.bak.$(date +%Y%m%d%H%M%S)"
  sed -i -E "s#(pkgs\.zabbly\.com/incus/)${ZABBLY_CHANNEL}#\1stable#g" "$ZABBLY_FILE"
  ok "软件源已从 ${ZABBLY_CHANNEL} 切换为 stable（原文件已备份为 $ZABBLY_FILE.bak.*）"
fi

# 备份数据库（体积通常很小）
BK="/root/incus-db-backup-$(date +%Y%m%d%H%M%S).tar.gz"
if [ -d /var/lib/incus/database ]; then
  tar -czf "$BK" -C /var/lib/incus database 2>/dev/null && ok "数据库已备份：$BK" || warn "数据库备份失败，继续前请自行备份。"
fi

PKGS="$(dpkg-query -W -f='${binary:Package} ${Status}\n' 'incus*' 2>/dev/null | awk '/install ok installed/{print $1}' | tr '\n' ' ')"
info "将升级的包：$PKGS"
echo "  升级期间 incus 守护进程会重启，运行中的容器/虚拟机一般不会被停止，但 API 会短暂不可用。"

OLD_VER="$SERVER_VER"
apt-get update -q || { bad "apt-get update 失败"; exit 1; }
CAND="$(apt-cache policy incus | awk '/Candidate:/{print $2}')"
info "仓库中的候选版本：$CAND"
# shellcheck disable=SC2086
DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade $PKGS || { bad "apt 升级失败，请查看上面的输出。"; exit 1; }

info "等待守护进程就绪..."
incus admin waitready --timeout=120 >/dev/null 2>&1 || sleep 5

NEW_VER="$(incus version 2>/dev/null | awk -F': *' '/[Ss]erver version/{print $2}' | tr -d '[:space:]')"
NEW_NUM="$(echo "$NEW_VER" | grep -oE '^[0-9]+(\.[0-9]+){1,2}')"

# =============================================================================
hdr "7. 升级结果"
# =============================================================================
if [ -z "$NEW_NUM" ]; then
  bad "升级后无法连接 incus 守护进程！请检查：systemctl status incus ; journalctl -u incus -n 100"
  [ -f "$BK" ] && echo "  数据库备份在：$BK"
  exit 1
fi

echo "  升级前：$OLD_VER"
echo "  升级后：${W}$NEW_VER${N}"

if ver_ge "$NEW_NUM" "$FIX_CVE_112816"; then
  echo
  echo "  ${G}${W}╔══════════════════════════════════════════════════════╗${N}"
  echo "  ${G}${W}║  ✓ 升级成功！Incus $NEW_VER 已修复 CVE-2026-112816   ${N}"
  echo "  ${G}${W}╚══════════════════════════════════════════════════════╝${N}"
  echo
  echo "  后续建议："
  echo "   1. 测试面板能否正常连接、创建/启停实例。"
  echo "   2. 7.6.0 起 VM 启动默认跳过网卡、PXE 默认关闭（需 boot.pxe），面板开 VM 时请验证。"
  echo "   3. 保持 8443 只对面板 IP 开放；如排查发现可疑迹象，重新签发面板证书并考虑重建主机。"
  echo "   4. stable 通道是月度版本，记得每月跟进升级。"
  exit 0
elif [ "$NEW_NUM" != "$(echo "$OLD_VER" | grep -oE '^[0-9]+(\.[0-9]+){1,2}')" ]; then
  echo
  echo "  ${Y}${W}△ 已升级到 $NEW_VER，修复了该版本包含的其它 CVE，${N}"
  echo "  ${Y}${W}  但 CVE-2026-112816 官方修复版本是 $FIX_CVE_112816，当前仍按受影响处理。${N}"
  echo "  请务必保持 8443 只对面板 IP 开放，并关注 LTS 补丁，或重新运行本脚本选择切换到 stable。"
  exit 1
else
  echo
  echo "  ${Y}${W}△ 版本没有变化：仓库中暂无更新的版本（候选 $CAND）。${N}"
  echo "  请先做防火墙止血；发行版仓库没有修复时可改用 Zabbly 官方源 https://github.com/zabbly/incus 。"
  exit 1
fi
