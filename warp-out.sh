#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "==========================================="
echo " OpenVPN 出口服务器自动部署脚本（v3.4 修复版）"
echo " ✔ 协议强制 IPv6 (udp6/tcp6)"
echo " ✔ 修复 SSH/SCP IPv6 地址格式"
echo " ✔ 修复 SCP 失败返回码与登录失败提示"
echo " ✔ 包含 NAT 修复与自动上传验证"
echo "==========================================="

PUB_IP6=$(ip -6 addr show | grep global | grep -v temporary | awk '{print $2}' | cut -d'/' -f1 | head -n 1)

if [[ -z "$PUB_IP6" ]]; then
    echo "❌ 未检测到公网 IPv6，无法作为出口节点"
    exit 1
fi

echo "检测到出口公网 IPv6: $PUB_IP6"

NIC=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
NIC=${NIC:-eth0}

echo "检测到出口网卡: $NIC"

apt update -y
apt install -y openvpn easy-rsa sshpass iptables-persistent

rm -rf /etc/openvpn/easy-rsa
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
cd /etc/openvpn/easy-rsa

export EASYRSA_BATCH=1
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa build-client-full client nopass
./easyrsa gen-dh
openvpn --genkey secret ta.key

cp pki/ca.crt /etc/openvpn/
cp pki/dh.pem /etc/openvpn/
cp pki/issued/server.crt /etc/openvpn/
cp pki/private/server.key /etc/openvpn/
cp pki/issued/client.crt /etc/openvpn/
cp pki/private/client.key /etc/openvpn/
cp ta.key /etc/openvpn/

UDP_PORT=1196
TCP_PORT=443

echo "使用 UDP 端口: $UDP_PORT"
echo "使用 TCP 端口: $TCP_PORT"

echo 1 >/proc/sys/net/ipv4/ip_forward
echo 1 >/proc/sys/net/ipv6/conf/all/forwarding

iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$NIC" -j MASQUERADE
iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o "$NIC" -j MASQUERADE
ip6tables -t nat -A POSTROUTING -s fd00:1234::/64 -o "$NIC" -j MASQUERADE

iptables-save >/etc/iptables/rules.v4
ip6tables-save >/etc/iptables/rules.v6

cat >/etc/openvpn/server.conf <<EOF
port $UDP_PORT
proto udp6
dev tun
topology subnet
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt ta.key
server 10.8.0.0 255.255.255.0
server-ipv6 fd00:1234::/64
push "redirect-gateway def1 ipv6 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS6 2606:4700:4700::1111"
cipher AES-256-GCM
auth SHA256
persist-key
persist-tun
explicit-exit-notify 1
verb 3
EOF

cat >/etc/openvpn/server-tcp.conf <<EOF
port $TCP_PORT
proto tcp6
dev tun
topology subnet
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-crypt ta.key
server 10.9.0.0 255.255.255.0
server-ipv6 fd00:1234::/64
push "redirect-gateway def1 ipv6 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS6 2606:4700:4700::1111"
cipher AES-256-GCM
auth SHA256
persist-key
persist-tun
verb 3
EOF

systemctl enable openvpn@server
systemctl restart openvpn@server
systemctl enable openvpn@server-tcp
systemctl restart openvpn@server-tcp

CLIENT=/root/client.ovpn

cat >"$CLIENT" <<EOF
client
dev tun
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth SHA256
auth-nocache
resolv-retry infinite

remote $PUB_IP6 $UDP_PORT udp6
remote $PUB_IP6 $TCP_PORT tcp6

<ca>
$(cat /etc/openvpn/ca.crt)
</ca>

<cert>
$(cat /etc/openvpn/client.crt)
</cert>

<key>
$(cat /etc/openvpn/client.key)
</key>

<tls-crypt>
$(cat /etc/openvpn/ta.key)
</tls-crypt>
EOF

echo "client.ovpn 已生成：/root/client.ovpn"

echo "=============== 上传 client.ovpn 到入口服务器 ==============="

read -p "入口服务器 IP（IPv6/IPv4，无需加[]）： " IN_IP
read -p "入口 SSH 端口（默认22）： " IN_PORT
IN_PORT=${IN_PORT:-22}
read -p "SSH 用户（默认 root）： " IN_USER
IN_USER=${IN_USER:-root}
read -s -p "SSH 密码： " IN_PASS
echo

CLEAN_IP=$(echo "$IN_IP" | tr -d '[]')
ssh-keygen -R "$CLEAN_IP" >/dev/null 2>&1 || true

upload_and_verify() {
    local RAW_IP=$1
    local SCP_HOST
    local TARGET_FILE="/root/client.ovpn"
    local SSH_OPTS=(-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1)

    if [[ "$RAW_IP" == *":"* ]]; then
        SCP_HOST="[${RAW_IP}]"
    else
        SCP_HOST="${RAW_IP}"
    fi

    echo "------------------------------------------------"
    echo ">>> 正在验证 SSH 登录..."
    echo "    SSH 目标: ${RAW_IP}"
    echo "    SCP 目标: ${SCP_HOST}"

    if ! sshpass -p "$IN_PASS" ssh -p "$IN_PORT" "${SSH_OPTS[@]}" \
        "${IN_USER}@${RAW_IP}" "echo ok" >/dev/null 2>&1; then
        echo "❌ SSH 登录失败：入口机器拒绝了当前账号/密码。"
        echo "   常见原因：密码错误、root 禁止密码登录、SSH 端口不对，或入口机器未允许 PasswordAuthentication。"
        echo "   你可以先手动确认：ssh -p $IN_PORT ${IN_USER}@${RAW_IP}"
        return 1
    fi

    echo ">>> SSH 登录验证通过，正在上传 client.ovpn..."
    set +e
    sshpass -p "$IN_PASS" scp -P "$IN_PORT" "${SSH_OPTS[@]}" \
        "$CLIENT" "${IN_USER}@${SCP_HOST}:${TARGET_FILE}"
    local SCP_STATUS=$?
    set -e

    if [ "$SCP_STATUS" -ne 0 ]; then
        echo "❌ SCP 上传失败 (返回码 $SCP_STATUS)。"
        return "$SCP_STATUS"
    fi

    echo ">>> SCP 上传完成，正在进行最终验证..."
    if sshpass -p "$IN_PASS" ssh -p "$IN_PORT" "${SSH_OPTS[@]}" \
        "${IN_USER}@${RAW_IP}" "test -s $TARGET_FILE && ls -lh $TARGET_FILE"; then
        echo "✅ 验证成功！文件确认存在于入口服务器。"
        return 0
    fi

    echo "❌ 验证失败：文件上传后远程检查未通过。"
    return 1
}

if upload_and_verify "$CLEAN_IP"; then
    echo "======================================================="
    echo "🚀 OpenVPN 出口节点部署完成！"
    echo "✅ client.ovpn 已成功传输并验证。"
    echo "👉 下一步：请登录入口服务器，运行 warp-in.sh"
    echo "======================================================="
else
    echo "======================================================="
    echo "❌ 自动上传最终失败。"
    echo "   请手动下载 /root/client.ovpn 并上传到入口服务器的 /root/ 目录"
    echo "======================================================="
fi
