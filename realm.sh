#!/bin/bash

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
SERVICE_FILE="/etc/systemd/system/realm-forward.service"
REALM_BIN=""
PKG_MANAGER=""
PKG_UPDATED=0

mkdir -p "$BASE_DIR" "$REALM_DIR"
touch "$RULES_FILE"

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

detect_pkg_manager() {
    if [[ -n "$PKG_MANAGER" ]]; then
        return 0
    fi
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MANAGER="apt"
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MANAGER="dnf"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
    else
        return 1
    fi
}

install_packages() {
    if [[ "$#" -eq 0 ]]; then
        return 0
    fi
    if ! detect_pkg_manager; then
        return 1
    fi
    case "$PKG_MANAGER" in
        apt)
            if [[ "$PKG_UPDATED" -eq 0 ]]; then
                apt-get update >/dev/null 2>&1 || true
                PKG_UPDATED=1
            fi
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" >/dev/null
            ;;
        dnf)
            dnf install -y "$@" >/dev/null
            ;;
        yum)
            yum install -y "$@" >/dev/null
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

arch_candidates() {
    case "$(uname -m)" in
        x86_64|amd64)
            echo "x86_64-unknown-linux-gnu x86_64-unknown-linux-musl"
            ;;
        aarch64|arm64)
            echo "aarch64-unknown-linux-gnu aarch64-unknown-linux-musl"
            ;;
        armv7l|armv7)
            echo "armv7-unknown-linux-gnueabihf armv7-unknown-linux-musleabihf"
            ;;
        armv6l|arm)
            echo "arm-unknown-linux-gnueabihf arm-unknown-linux-musleabihf arm-unknown-linux-gnueabi"
            ;;
        *)
            return 1
            ;;
    esac
}

ensure_realm() {
    if command -v realm >/dev/null 2>&1; then
        REALM_BIN="$(command -v realm)"
        return 0
    fi

    print_info "未发现 realm，准备安装"
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

    local candidates=""
    if ! candidates="$(arch_candidates)"; then
        print_err "当前系统架构暂不支持自动安装 realm"
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
        print_err "未找到当前架构可用的 realm 安装包"
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

    install -m 0755 "$realm_path" /usr/local/bin/realm
    rm -rf "$tmp_dir"
    REALM_BIN="/usr/local/bin/realm"
    print_ok "realm 安装完成"
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
    return 0
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
    local local_mode="$PORT_MODE"
    local local_start="$PORT_START"
    local local_end="$PORT_END"

    parse_port_token "$remote_token" || return 1
    local remote_mode="$PORT_MODE"
    local remote_start="$PORT_START"
    local remote_end="$PORT_END"

    if [[ "$local_mode" == "single" && "$remote_mode" == "single" ]]; then
        append_endpoint "$cfg_file" "$local_start" "$remote_host" "$remote_start"
        return 0
    fi

    if [[ "$local_mode" == "range" && "$remote_mode" == "single" ]]; then
        local p
        for (( p=local_start; p<=local_end; p++ )); do
            append_endpoint "$cfg_file" "$p" "$remote_host" "$remote_start"
        done
        return 0
    fi

    if [[ "$local_mode" == "range" && "$remote_mode" == "range" ]]; then
        local local_len=$(( local_end - local_start ))
        local remote_len=$(( remote_end - remote_start ))
        if (( local_len != remote_len )); then
            return 1
        fi
        local i
        for (( i=0; i<=local_len; i++ )); do
            append_endpoint "$cfg_file" "$((local_start + i))" "$remote_host" "$((remote_start + i))"
        done
        return 0
    fi

    if [[ "$local_mode" == "single" && "$remote_mode" == "range" ]]; then
        append_endpoint "$cfg_file" "$local_start" "$remote_host" "$remote_start"
        return 0
    fi

    return 1
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

    local line
    local line_no=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_no=$((line_no + 1))
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        if [[ "$line" != *">"* || "$line" != *":"* ]]; then
            print_warn "忽略无效规则(第 ${line_no} 行): $line"
            continue
        fi

        local local_token="${line%%>*}"
        local right="${line#*>}"
        local remote_host="${right%:*}"
        local remote_token="${right##*:}"

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
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Realm 端口转发服务
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
}

apply_service() {
    ensure_realm || return 1
    build_realm_config
    write_service_file
    systemctl daemon-reload
    systemctl enable realm-forward >/dev/null 2>&1 || true
    systemctl restart realm-forward
    print_ok "realm 转发服务已刷新"
}

show_header() {
    clear
    echo -e "${CYAN}====================================================${PLAIN}"
    echo -e "${CYAN} Realm 端口转发管理脚本${PLAIN}"
    echo -e "${CYAN} 规则格式: 本地端口>目标主机:目标端口${PLAIN}"
    echo -e "${CYAN} 例子: 8080>1.2.3.4:80  或 10000-10010>example.com:20000-20010${PLAIN}"
    echo -e "${CYAN}====================================================${PLAIN}"
    echo ""
}

add_rule() {
    echo -e " ${CYAN}请选择转发模式${PLAIN}"
    echo -e "  ${GREEN}1.${PLAIN} 单端口"
    echo -e "  ${GREEN}2.${PLAIN} 全范围(10000-65535)"
    echo -e "  ${GREEN}3.${PLAIN} 自定义范围"
    echo -ne " ${CYAN}输入选项[1-3]: ${PLAIN}"
    read -r mode

    local local_token=""
    local remote_token=""
    local remote_host=""

    case "$mode" in
        1)
            echo -ne " ${CYAN}输入本地端口: ${PLAIN}"
            read -r local_token
            echo -ne " ${CYAN}输入目标端口: ${PLAIN}"
            read -r remote_token
            ;;
        2)
            local_token="10000-65535"
            remote_token="10000-65535"
            print_info "已选择范围 10000-65535"
            ;;
        3)
            local start_port
            local end_port
            echo -ne " ${CYAN}输入起始端口: ${PLAIN}"
            read -r start_port
            echo -ne " ${CYAN}输入结束端口: ${PLAIN}"
            read -r end_port
            local_token="${start_port}-${end_port}"
            remote_token="${start_port}-${end_port}"
            ;;
        *)
            print_err "无效选项"
            sleep 1
            return 1
            ;;
    esac

    echo -ne " ${CYAN}输入目标主机(IP或域名): ${PLAIN}"
    read -r remote_host

    if ! parse_port_token "$local_token"; then
        print_err "本地端口格式错误"
        sleep 1
        return 1
    fi
    if ! parse_port_token "$remote_token"; then
        print_err "目标端口格式错误"
        sleep 1
        return 1
    fi
    if [[ -z "$remote_host" ]]; then
        print_err "目标主机不能为空"
        sleep 1
        return 1
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
    local local_token
    read -r local_token

    if [[ -z "$local_token" ]]; then
        print_err "输入不能为空"
        sleep 1
        return 1
    fi

    local before_count
    local after_count
    before_count="$(wc -l < "$RULES_FILE")"
    sed -i "\|^${local_token}>|d" "$RULES_FILE"
    after_count="$(wc -l < "$RULES_FILE")"

    if [[ "$before_count" == "$after_count" ]]; then
        print_warn "未找到对应规则"
        sleep 1
        return 0
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
        print_info "已取消"
        sleep 1
        return 0
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
    systemctl --no-pager -l status realm-forward || true
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
                if apply_service; then
                    print_ok "服务已刷新"
                else
                    print_err "服务刷新失败"
                fi
                sleep 1
                ;;
            0) exit 0 ;;
            *)
                print_err "无效选项"
                sleep 1
                ;;
        esac
    done
}

require_root
main_menu
