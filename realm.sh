#!/bin/sh

# Alpine does not include Bash by default. Bootstrap it before Bash parses the
# rest of this file. This also lets the script be launched with either sh or bash.
if [ -z "${BASH_VERSION:-}" ]; then
    if [ ! -r /etc/os-release ]; then
        printf '%s\n' '[错误] 无法识别系统：缺少 /etc/os-release' >&2
        exit 1
    fi

    OS_ID="$(. /etc/os-release; printf '%s' "${ID:-}")"
    if [ "$(id -u)" -ne 0 ]; then
        printf '%s\n' '[错误] 请使用 root 运行脚本' >&2
        exit 1
    fi

    case "$OS_ID" in
        alpine)
            printf '%s\n' '[提示] 检测到 Alpine，正在安装 Bash...'
            apk add --no-cache bash >/dev/null || exit 1
            ;;
        debian|ubuntu)
            printf '%s\n' "[提示] 检测到 ${OS_ID}，正在安装 Bash..."
            apt-get update >/dev/null || exit 1
            DEBIAN_FRONTEND=noninteractive apt-get install -y bash >/dev/null || exit 1
            ;;
        *)
            printf '%s\n' "[错误] 暂不支持此系统：${OS_ID:-unknown}（仅支持 Alpine、Debian、Ubuntu）" >&2
            exit 1
            ;;
    esac

    exec bash "$0" "$@"
fi

set -euo pipefail

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
PLAIN='\033[0m'

SUCCESS="[${GREEN}成功${PLAIN}]"
INFO="[${CYAN}提示${PLAIN}]"
WARN="[${YELLOW}警告${PLAIN}]"
ERROR="[${RED}错误${PLAIN}]"

BASE_DIR="/etc/realm-forward"
RULES_FILE="$BASE_DIR/rules.conf"
REALM_DIR="/etc/realm"
CONFIG_FILE="$REALM_DIR/config.toml"
REALM_BIN=""
OS_ID=""
OS_NAME=""
PKG_MANAGER=""
SERVICE_MANAGER=""
SERVICE_FILE=""
PKG_UPDATED=0

print_info() { echo -e "${INFO} $*"; }
print_ok() { echo -e "${SUCCESS} $*"; }
print_warn() { echo -e "${WARN} $*"; }
print_err() { echo -e "${ERROR} $*"; }

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        print_err "请使用 root 运行脚本"
        exit 1
    fi
}

detect_system() {
    if [[ ! -r /etc/os-release ]]; then
        print_err "无法识别系统：缺少 /etc/os-release"
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-}"
    OS_NAME="${PRETTY_NAME:-$OS_ID}"

    case "$OS_ID" in
        alpine)
            PKG_MANAGER="apk"
            SERVICE_MANAGER="openrc"
            SERVICE_FILE="/etc/init.d/realm-forward"
            ;;
        debian|ubuntu)
            PKG_MANAGER="apt"
            SERVICE_MANAGER="systemd"
            SERVICE_FILE="/etc/systemd/system/realm-forward.service"
            ;;
        *)
            print_err "暂不支持此系统：${OS_NAME:-unknown}"
            print_info "当前仅支持 Alpine、Debian 和 Ubuntu"
            exit 1
            ;;
    esac

    print_ok "已识别系统：$OS_NAME（服务管理：$SERVICE_MANAGER）"
}

install_packages() {
    if [[ "$#" -eq 0 ]]; then
        return 0
    fi

    case "$PKG_MANAGER" in
        apt)
            if [[ "$PKG_UPDATED" -eq 0 ]]; then
                print_info "正在更新软件包索引"
                apt-get update >/dev/null
                PKG_UPDATED=1
            fi
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null
            ;;
        apk)
            apk add --no-cache "$@" >/dev/null
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_cmd() {
    local cmd="$1"
    shift
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    fi
    install_packages "$@" || true
    command -v "$cmd" >/dev/null 2>&1
}

ensure_service_manager() {
    case "$SERVICE_MANAGER" in
        systemd)
            if ! command -v systemctl >/dev/null 2>&1; then
                print_err "当前 Debian/Ubuntu 环境未运行 systemd，无法创建系统服务"
                return 1
            fi
            ;;
        openrc)
            if ! command -v rc-service >/dev/null 2>&1; then
                print_info "未发现 OpenRC，准备安装"
                install_packages openrc || true
            fi
            if ! command -v rc-service >/dev/null 2>&1 || ! command -v rc-update >/dev/null 2>&1; then
                print_err "OpenRC 安装失败，无法创建系统服务"
                return 1
            fi
            ;;
    esac
}

arch_candidates() {
    local gnu_target=""
    local musl_target=""

    case "$(uname -m)" in
        x86_64|amd64)
            gnu_target="x86_64-unknown-linux-gnu"
            musl_target="x86_64-unknown-linux-musl"
            ;;
        aarch64|arm64)
            gnu_target="aarch64-unknown-linux-gnu"
            musl_target="aarch64-unknown-linux-musl"
            ;;
        armv7l|armv7)
            gnu_target="armv7-unknown-linux-gnueabihf"
            musl_target="armv7-unknown-linux-musleabihf"
            ;;
        armv6l|arm)
            gnu_target="arm-unknown-linux-gnueabihf arm-unknown-linux-gnueabi"
            musl_target="arm-unknown-linux-musleabihf"
            ;;
        *)
            return 1
            ;;
    esac

    if [[ "$OS_ID" == "alpine" ]]; then
        echo "$musl_target $gnu_target"
    else
        echo "$gnu_target $musl_target"
    fi
}

ensure_realm() {
    if command -v realm >/dev/null 2>&1; then
        REALM_BIN="$(command -v realm)"
        return 0
    fi

    print_info "未发现 realm，准备安装"
    install_packages ca-certificates >/dev/null 2>&1 || true
    if ! ensure_cmd curl curl; then
        print_err "缺少 curl，且自动安装失败"
        return 1
    fi
    if ! ensure_cmd tar tar; then
        print_err "缺少 tar，且自动安装失败"
        return 1
    fi

    local api_url="https://api.github.com/repos/zhboner/realm/releases/latest"
    local release_json
    if ! release_json="$(curl -fsSL "$api_url")"; then
        print_err "获取 realm 发布信息失败"
        return 1
    fi

    local candidates
    if ! candidates="$(arch_candidates)"; then
        print_err "当前系统架构 $(uname -m) 暂不支持自动安装 realm"
        return 1
    fi

    local asset_url=""
    local target
    for target in $candidates; do
        asset_url="$(printf '%s\n' "$release_json" | grep -Eo "https://[^\"]+realm-${target}\.tar\.gz" | head -n 1 || true)"
        if [[ -n "$asset_url" ]]; then
            break
        fi
    done

    if [[ -z "$asset_url" ]]; then
        print_err "未找到当前系统及架构可用的 realm 安装包"
        return 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local archive="$tmp_dir/realm.tar.gz"

    if ! curl -fL "$asset_url" -o "$archive"; then
        rm -rf "$tmp_dir"
        print_err "realm 下载失败"
        return 1
    fi
    if ! tar -xzf "$archive" -C "$tmp_dir"; then
        rm -rf "$tmp_dir"
        print_err "realm 解压失败"
        return 1
    fi

    local realm_path=""
    if [[ -f "$tmp_dir/realm" ]]; then
        realm_path="$tmp_dir/realm"
    else
        realm_path="$(find "$tmp_dir" -maxdepth 3 -type f -name realm | head -n 1 || true)"
    fi
    if [[ -z "$realm_path" || ! -f "$realm_path" ]]; then
        rm -rf "$tmp_dir"
        print_err "未在安装包中找到 realm 可执行文件"
        return 1
    fi

    cp "$realm_path" /usr/local/bin/realm
    chmod 0755 /usr/local/bin/realm
    rm -rf "$tmp_dir"
    REALM_BIN="/usr/local/bin/realm"
    print_ok "realm 安装完成（使用 ${target} 版本）"
}

PORT_MODE=""
PORT_START=0
PORT_END=0

parse_port_token() {
    local token="$1"
    if [[ "$token" =~ ^([0-9]{1,5})$ ]]; then
        PORT_MODE="single"
        PORT_START="${BASH_REMATCH[1]}"
        PORT_END="${BASH_REMATCH[1]}"
    elif [[ "$token" =~ ^([0-9]{1,5})-([0-9]{1,5})$ ]]; then
        PORT_MODE="range"
        PORT_START="${BASH_REMATCH[1]}"
        PORT_END="${BASH_REMATCH[2]}"
    else
        return 1
    fi

    if (( PORT_START < 1 || PORT_START > 65535 || PORT_END < 1 || PORT_END > 65535 || PORT_START > PORT_END )); then
        return 1
    fi
}

append_endpoint() {
    local cfg_file="$1"
    local listen_port="$2"
    local remote_host="$3"
    local remote_port="$4"
    cat >> "$cfg_file" <<EOF
[[endpoints]]
listen = "0.0.0.0:${listen_port}"
remote = "${remote_host}:${remote_port}"
EOF
}

append_rule_to_config() {
    local cfg_file="$1"
    local local_token="$2"
    local remote_host="$3"
    local remote_token="$4"

    parse_port_token "$local_token" || return 1
    local local_mode="$PORT_MODE" local_start="$PORT_START" local_end="$PORT_END"
    parse_port_token "$remote_token" || return 1
    local remote_mode="$PORT_MODE" remote_start="$PORT_START" remote_end="$PORT_END"

    if [[ "$local_mode" == "single" && "$remote_mode" == "single" ]]; then
        append_endpoint "$cfg_file" "$local_start" "$remote_host" "$remote_start"
    elif [[ "$local_mode" == "range" && "$remote_mode" == "single" ]]; then
        local p
        for (( p=local_start; p<=local_end; p++ )); do
            append_endpoint "$cfg_file" "$p" "$remote_host" "$remote_start"
        done
    elif [[ "$local_mode" == "range" && "$remote_mode" == "range" ]]; then
        local local_len=$((local_end - local_start))
        local remote_len=$((remote_end - remote_start))
        (( local_len == remote_len )) || return 1
        local i
        for (( i=0; i<=local_len; i++ )); do
            append_endpoint "$cfg_file" "$((local_start + i))" "$remote_host" "$((remote_start + i))"
        done
    elif [[ "$local_mode" == "single" && "$remote_mode" == "range" ]]; then
        append_endpoint "$cfg_file" "$local_start" "$remote_host" "$remote_start"
    else
        return 1
    fi
}

build_realm_config() {
    local tmp_cfg="${CONFIG_FILE}.tmp"
    cat > "$tmp_cfg" <<EOF
[log]
level = "warn"

[network]
no_tcp = false
use_udp = true
EOF

    local line local_token right remote_host remote_token
    local line_no=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_no=$((line_no + 1))
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
        if [[ "$line" != *">"* || "$line" != *":"* ]]; then
            print_warn "忽略无效规则(第 ${line_no} 行): $line"
            continue
        fi

        local_token="${line%%>*}"
        right="${line#*>}"
        remote_host="${right%:*}"
        remote_token="${right##*:}"
        if [[ -z "$local_token" || -z "$remote_host" || -z "$remote_token" ]]; then
            print_warn "忽略无效规则(第 ${line_no} 行): $line"
            continue
        fi
        if ! append_rule_to_config "$tmp_cfg" "$local_token" "$remote_host" "$remote_token"; then
            print_warn "忽略端口格式不正确的规则(第 ${line_no} 行): $line"
        fi
    done < "$RULES_FILE"

    mv "$tmp_cfg" "$CONFIG_FILE"
}

write_service_file() {
    if [[ "$SERVICE_MANAGER" == "systemd" ]]; then
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Realm port forwarding service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${REALM_BIN} -c ${CONFIG_FILE}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > "$SERVICE_FILE" <<EOF
#!/sbin/openrc-run

description="Realm port forwarding service"
command="${REALM_BIN}"
command_args="-c ${CONFIG_FILE}"
command_background="yes"
pidfile="/run/realm-forward.pid"
output_log="/var/log/realm-forward.log"
error_log="/var/log/realm-forward.log"

depend() {
    need net
}
EOF
        chmod 0755 "$SERVICE_FILE"
    fi
}

apply_service() {
    ensure_service_manager || return 1
    ensure_realm || return 1
    build_realm_config
    write_service_file

    if [[ "$SERVICE_MANAGER" == "systemd" ]]; then
        systemctl daemon-reload
        systemctl enable realm-forward >/dev/null 2>&1 || true
        systemctl restart realm-forward
    else
        rc-update add realm-forward default >/dev/null 2>&1 || true
        rc-service realm-forward stop >/dev/null 2>&1 || true
        rc-service realm-forward start
    fi
    print_ok "realm 转发服务已刷新"
}

show_header() {
    if command -v clear >/dev/null 2>&1; then clear; fi
    echo -e "${CYAN}====================================================${PLAIN}"
    echo -e "${CYAN} Realm 端口转发管理脚本${PLAIN}"
    echo -e "${CYAN} 系统: ${OS_NAME} | 服务: ${SERVICE_MANAGER}${PLAIN}"
    echo -e "${CYAN} 规则格式: 本地端口>目标主机:目标端口${PLAIN}"
    echo -e "${CYAN} 例子: 8080>1.2.3.4:80 或 10000-10010>example.com:20000-20010${PLAIN}"
    echo -e "${CYAN}====================================================${PLAIN}"
    echo ""
}

add_rule() {
    echo -e " ${CYAN}请选择转发模式${PLAIN}"
    echo -e "  ${GREEN}1.${PLAIN} 单端口"
    echo -e "  ${GREEN}2.${PLAIN} 全范围(10000-65535)"
    echo -e "  ${GREEN}3.${PLAIN} 自定义范围"
    echo -ne " ${CYAN}输入选项[1-3]: ${PLAIN}"
    local mode
    read -r mode

    local local_token="" remote_token="" remote_host=""
    case "$mode" in
        1)
            echo -ne " ${CYAN}输入本地端口: ${PLAIN}"; read -r local_token
            echo -ne " ${CYAN}输入目标端口: ${PLAIN}"; read -r remote_token
            ;;
        2)
            local_token="10000-65535"
            remote_token="10000-65535"
            print_info "已选择范围 10000-65535"
            ;;
        3)
            local start_port end_port
            echo -ne " ${CYAN}输入起始端口: ${PLAIN}"; read -r start_port
            echo -ne " ${CYAN}输入结束端口: ${PLAIN}"; read -r end_port
            local_token="${start_port}-${end_port}"
            remote_token="${start_port}-${end_port}"
            ;;
        *)
            print_err "无效选项"; sleep 1; return 1
            ;;
    esac

    echo -ne " ${CYAN}输入目标主机(IP或域名): ${PLAIN}"
    read -r remote_host
    if ! parse_port_token "$local_token"; then
        print_err "本地端口格式错误"; sleep 1; return 1
    fi
    if ! parse_port_token "$remote_token"; then
        print_err "目标端口格式错误"; sleep 1; return 1
    fi
    if [[ -z "$remote_host" ]]; then
        print_err "目标主机不能为空"; sleep 1; return 1
    fi

    sed -i "\|^${local_token}>.*$|d" "$RULES_FILE"
    echo "${local_token}>${remote_host}:${remote_token}" >> "$RULES_FILE"
    if apply_service; then
        print_ok "规则已添加: ${local_token} -> ${remote_host}:${remote_token}"
    else
        print_err "规则已写入，但服务刷新失败，请检查日志"
    fi
    sleep 1
}

remove_rule() {
    echo -ne " ${CYAN}输入要删除的本地端口或范围: ${PLAIN}"
    local local_token before_count after_count
    read -r local_token
    if [[ -z "$local_token" ]]; then
        print_err "输入不能为空"; sleep 1; return 1
    fi

    before_count="$(wc -l < "$RULES_FILE")"
    sed -i "\|^${local_token}>|d" "$RULES_FILE"
    after_count="$(wc -l < "$RULES_FILE")"
    if [[ "$before_count" == "$after_count" ]]; then
        print_warn "未找到对应规则"; sleep 1; return 0
    fi

    if apply_service; then
        print_ok "规则已删除: ${local_token}"
    else
        print_err "规则已删除，但服务刷新失败，请检查日志"
    fi
    sleep 1
}

list_rules() {
    echo -e " ${CYAN}当前规则列表${PLAIN}"
    if [[ ! -s "$RULES_FILE" ]]; then
        echo -e " ${YELLOW}暂无规则${PLAIN}"
    else
        nl -w2 -s'. ' "$RULES_FILE"
    fi
    echo ""
    echo -ne " ${INFO} 按回车返回..."
    read -r
}

clear_rules() {
    echo -ne " ${WARN}确认清空全部规则? [y/N]: ${PLAIN}"
    local confirm
    read -r confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "已取消"; sleep 1; return 0
    fi

    : > "$RULES_FILE"
    if apply_service; then
        print_ok "全部规则已清空"
    else
        print_err "规则已清空，但服务刷新失败，请检查日志"
    fi
    sleep 1
}

show_status() {
    echo -e " ${CYAN}服务状态${PLAIN}"
    if [[ "$SERVICE_MANAGER" == "systemd" ]]; then
        systemctl --no-pager -l status realm-forward || true
    else
        rc-service realm-forward status || true
        if [[ -f /var/log/realm-forward.log ]]; then
            echo ""
            echo -e " ${CYAN}最近日志${PLAIN}"
            tail -n 20 /var/log/realm-forward.log
        fi
    fi
    echo ""
    echo -e " ${CYAN}配置文件: ${CONFIG_FILE}${PLAIN}"
    echo -e " ${CYAN}规则文件: ${RULES_FILE}${PLAIN}"
    echo ""
    echo -ne " ${INFO} 按回车返回..."
    read -r
}

main_menu() {
    while true; do
        show_header
        echo -e "  ${GREEN}1.${PLAIN} 添加转发规则"
        echo -e "  ${GREEN}2.${PLAIN} 删除转发规则"
        echo -e "  ${GREEN}3.${PLAIN} 查看当前规则"
        echo -e "  ${GREEN}4.${PLAIN} 查看服务状态"
        echo -e "  ${GREEN}5.${PLAIN} 清空全部规则"
        echo -e "  ${YELLOW}6.${PLAIN} 刷新服务(重读规则)"
        echo -e "  ${RED}0.${PLAIN} 退出"
        echo ""
        echo -ne " ${CYAN}输入选项[0-6]: ${PLAIN}"
        local opt
        read -r opt
        case "$opt" in
            1) add_rule ;;
            2) remove_rule ;;
            3) list_rules ;;
            4) show_status ;;
            5) clear_rules ;;
            6)
                if apply_service; then print_ok "服务已刷新"; else print_err "服务刷新失败"; fi
                sleep 1
                ;;
            0) exit 0 ;;
            *) print_err "无效选项"; sleep 1 ;;
        esac
    done
}

require_root
detect_system
mkdir -p "$BASE_DIR" "$REALM_DIR"
touch "$RULES_FILE"
main_menu
