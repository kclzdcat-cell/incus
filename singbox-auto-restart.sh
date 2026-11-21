#!/usr/bin/env bash
set -euo pipefail

stage=$(mktemp -d)
complete=no
trap 'rc=$?; rm -rf -- "$stage"; if [[ "$complete" != yes && "$rc" == 0 ]]; then echo "安装脚本不完整，请重新下载。" >&2; exit 1; fi' EXIT

cat > "$stage/manager.sh" <<'SINGBOX_RESTART_MANAGER'
#!/usr/bin/env bash
set -euo pipefail

command_path=/usr/local/bin/singbox-restart
unit_dir=/etc/systemd/system
service=singbox-auto-restart.service
timer=singbox-auto-restart.timer
targets=(sing-box.service keep-alive.service)

if (( EUID != 0 )); then
    echo '请以 root 身份运行，或使用 sudo。' >&2
    exit 1
fi

write_unit() {
    local tmp
    tmp=$(mktemp "$unit_dir/.singbox-restart.XXXXXX")
    if ! cat > "$tmp" || ! chmod 0644 "$tmp" || ! mv -f -- "$tmp" "$unit_dir/$1"; then
        rm -f -- "$tmp"
        return 1
    fi
}

check_services() {
    local unit state
    for unit in "${targets[@]}"; do
        state=$(systemctl show --property=LoadState --value "$unit") || return
        if [[ "$state" != loaded ]]; then
            echo "无法加载 $unit（$state）。" >&2
            return 1
        fi
    done
}

restart_services() {
    local unit needs_reload reload=no
    for unit in "${targets[@]}"; do
        needs_reload=$(systemctl show --property=NeedDaemonReload --value "$unit") || return
        case "$needs_reload" in
            yes) reload=yes ;;
            no) ;;
            *) echo "无法判断 $unit 是否需要重新加载。" >&2; return 1 ;;
        esac
    done
    if [[ "$reload" == yes ]]; then
        echo '服务定义已变更，执行 daemon-reload。'
        systemctl daemon-reload || return
    fi
    check_services || return
    echo '正在重启 sing-box 和 keep-alive。'
    systemctl restart "${targets[@]}" || return
    echo 'systemctl restart 执行成功。'
}

write_timer() {
    local hours=$1
    if [[ ! "$hours" =~ ^[1-9][0-9]{0,3}$ ]]; then
        echo '请输入 1 到 9999 的整数小时。' >&2
        return 1
    fi
    write_unit "$timer" <<EOF
[Unit]
Description=Periodic restart of sing-box and keep-alive

[Timer]
OnActiveSec=${hours}h
OnUnitActiveSec=${hours}h
AccuracySec=1s
Unit=$service

[Install]
WantedBy=timers.target
EOF
}

show_status() {
    local interval state enabled
    interval=$(sed -n 's/^OnActiveSec=//p' "$unit_dir/$timer")
    enabled=$(systemctl is-enabled "$timer" 2>/dev/null || true)
    state=$(systemctl is-active "$timer" 2>/dev/null || true)
    printf '间隔 %s | 定时器 %s | 开机启动 %s\n' "$interval" "$state" "$enabled"
    systemctl list-timers --all --no-pager "$timer"
}

set_interval() {
    local hours
    read -r -p '请输入新的间隔小时数：' hours || return 1
    write_timer "$hours" || return
    systemctl daemon-reload || return
    if systemctl is-active --quiet "$timer"; then
        systemctl restart "$timer" || return
    fi
    show_status
}

menu() {
    local choice confirm
    while true; do
        printf '\n1. 查看定时器状态和下次重启时间\n2. 修改重启间隔\n3. 查看最近 50 行重启日志\n4. 启用定时重启\n5. 暂停定时重启\n6. 立即重启 sing-box 和 keep-alive\n0. 退出\n'
        read -r -p '请选择：' choice || return 0
        case "$choice" in
            1) show_status || echo '查询失败。' >&2 ;;
            2) set_interval || echo '修改间隔失败。' >&2 ;;
            3) journalctl -u "$service" -n 50 --no-pager || echo '读取日志失败。' >&2 ;;
            4) systemctl enable --now "$timer" && show_status || echo '启用失败。' >&2 ;;
            5) systemctl disable --now "$timer" && show_status || echo '暂停失败。' >&2 ;;
            6)
                read -r -p '立即重启可能中断现有连接，继续？[y/N] ' confirm || return 0
                if [[ "$confirm" == [yY] ]]; then
                    systemctl start "$service" && echo '重启完成。' || echo '重启失败，请查看选项 3 的日志。' >&2
                fi
                ;;
            0) return 0 ;;
            *) echo '请输入菜单中的序号。' ;;
        esac
    done
}

if [[ "${1:-}" == --run ]]; then
    restart_services
    exit
fi

if [[ "${BASH_SOURCE[0]}" -ef "$command_path" ]] && (( $# == 0 )); then
    menu
    exit
fi

if (( $# > 1 )) || [[ ! "${1:-4}" =~ ^[1-9][0-9]{0,3}$ ]]; then
    echo '安装用法：bash singbox-auto-restart.sh [间隔小时数]' >&2
    exit 1
fi

check_services
fresh=no
if [[ ! -f "$unit_dir/$timer" ]]; then
    fresh=yes
fi
if [[ ! "${BASH_SOURCE[0]}" -ef "$command_path" ]]; then
    candidate=$(mktemp "${command_path}.XXXXXX")
    trap 'rm -f -- "$candidate"' EXIT
    install -m 0755 "${BASH_SOURCE[0]}" "$candidate"
    mv -f -- "$candidate" "$command_path"
fi

write_unit "$service" <<EOF
[Unit]
Description=Restart sing-box and keep-alive

[Service]
Type=oneshot
ExecStart=$command_path --run
EOF

if [[ "$fresh" == yes ]] || (( $# == 1 )); then
    write_timer "${1:-4}"
fi
systemctl daemon-reload
if [[ "$fresh" == yes ]]; then
    systemctl enable --now "$timer"
elif (( $# == 1 )) && systemctl is-active --quiet "$timer"; then
    systemctl restart "$timer"
fi
show_status
echo '安装完成。以后输入 singbox-restart 打开管理菜单。'
# END_SINGBOX_RESTART_MANAGER
SINGBOX_RESTART_MANAGER

if [[ "$(tail -n 1 "$stage/manager.sh")" != '# END_SINGBOX_RESTART_MANAGER' ]]; then
    echo '管理器下载不完整，请重新下载后执行。' >&2
    exit 1
fi
bash -n "$stage/manager.sh"
bash "$stage/manager.sh" "$@"
complete=yes
