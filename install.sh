#!/bin/bash
set -e

# ===== 기본 설정 (YAML 대신 직접 변수 정의) =====
INTERFACE="wlan0"
STATIC_IP="192.168.4.1/24"
PROFILE_NAME="captive"
SSID="Mario76-captive"
PASSWORD="your-password"
CHANNEL="6"

# ===== 파일 경로 =====
DHCPCD_FILE="/etc/dhcpcd.conf"
NM_CONF="/etc/NetworkManager/NetworkManager.conf"
DNSMASQ_DIR="/etc/NetworkManager/dnsmasq-shared.d"
DNSMASQ_FILE="$DNSMASQ_DIR/dnsmasq.conf"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"   # 현재 설치 디렉토리 절대경로
SYSTEMD_DIR="/etc/systemd/system"
ENV_FILE="/etc/default/captive-flask"

# ===== 함수들 =====
backup() {
    local path="$1"
    [ ! -f "$path" ] && return
    i=0
    while true; do
        suffix=$([ $i -eq 0 ] && echo ".backup" || echo ".backup.$i")
        dest="${path}${suffix}"
        if [ ! -f "$dest" ]; then
            cp "$path" "$dest"
            echo "[BACKUP] $path → $dest"
            break
        fi
        i=$((i+1))
    done
}

write_template() {
    local template_file="$1"
    local dest_file="$2"
    shift 2
    cp "$template_file" "$dest_file"
    for kv in "$@"; do
        key="${kv%%=*}"
        val="${kv#*=}"
        sed -i "s|{{$key}}|$val|g" "$dest_file"
    done
    echo "[WRITE] $dest_file"
}

# ===== dhcpcd.conf =====
backup "$DHCPCD_FILE"
write_template "./config/dhcpcd.conf.template" "$DHCPCD_FILE" \
    interface="$INTERFACE" static_ip="$STATIC_IP"

# ===== dnsmasq =====
mkdir -p "$DNSMASQ_DIR"
backup "$DNSMASQ_FILE"
write_template "./config/dnsmasq.conf.template" "$DNSMASQ_FILE" \
    interface="$INTERFACE" ip="${STATIC_IP%%/*}"

# ===== NetworkManager =====
backup "$NM_CONF"
if ! grep -q "dns=dnsmasq" "$NM_CONF" 2>/dev/null; then
    cat "./config/nm.conf.template" >> "$NM_CONF"
    echo "[APPEND] dns=dnsmasq to NetworkManager.conf"
fi

systemctl restart NetworkManager || true

# ===== nmcli AP 설정 =====
nmcli connection delete "$PROFILE_NAME" || true
nmcli connection add type wifi ifname "$INTERFACE" con-name "$PROFILE_NAME" autoconnect yes ssid "$SSID"
nmcli connection modify "$PROFILE_NAME" 802-11-wireless.mode ap
nmcli connection modify "$PROFILE_NAME" 802-11-wireless.band bg
nmcli connection modify "$PROFILE_NAME" 802-11-wireless.channel "$CHANNEL"
nmcli connection modify "$PROFILE_NAME" wifi-sec.key-mgmt wpa-psk
nmcli connection modify "$PROFILE_NAME" wifi-sec.psk "$PASSWORD"
nmcli connection modify "$PROFILE_NAME" ipv4.method shared
nmcli connection modify "$PROFILE_NAME" ipv4.addresses "$STATIC_IP"
nmcli connection modify "$PROFILE_NAME" ipv6.method auto

echo
echo "[OK] Captive portal configuration completed."
echo
echo "[INFO] Installing captive-flask.service with BASE_DIR=$BASE_DIR"

# 환경파일 작성
echo "BASE_DIR=$BASE_DIR" | sudo tee "$ENV_FILE" > /dev/null

# 서비스/디스패처 복사
sudo cp "$BASE_DIR/systemd/captive-flask.service" "$SYSTEMD_DIR/"

# ===== captive-flask-monitor 설치 (프로젝트 디렉토리에서 복사) =====
echo "[INFO] Installing captive-flask-monitor..."

# 모니터 스크립트 복사
sudo cp "$BASE_DIR/systemd/captive-flask-monitor.sh" /usr/local/bin/
sudo chmod +x /usr/local/bin/captive-flask-monitor.sh
echo "[COPY] captive-flask-monitor.sh → /usr/local/bin/"

# systemd 유닛 파일 복사
sudo cp "$BASE_DIR/systemd/captive-flask-monitor.service" /etc/systemd/system/
echo "[COPY] captive-flask-monitor.service → /etc/systemd/system/"

# systemd 리로드 및 활성화
sudo systemctl daemon-reload
sudo systemctl enable captive-flask.service
sudo systemctl enable captive-flask-monitor.service
sudo systemctl start captive-flask-monitor.service

echo "[INFO] Done. If disconnected from Wi-Fi for 10 seconds, captive-flask.service will be started."
