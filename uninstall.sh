#!/bin/bash
set -e

# ===== 경로 정의 =====
SYSTEMD_DIR="/etc/systemd/system"
DISPATCH_DIR="/etc/NetworkManager/dispatcher.d"
ENV_FILE="/etc/default/captive-flask"
MONITOR_SCRIPT="/usr/local/bin/captive-flask-monitor.sh"
MONITOR_SERVICE="$SYSTEMD_DIR/captive-flask-monitor.service"
CAPTIVE_PROFILE="captive"

echo "[INFO] Disabling services..."

# Flask 서비스 및 monitor 서비스 비활성화
sudo systemctl disable captive-flask.service 2>/dev/null || true
sudo systemctl stop captive-flask.service 2>/dev/null || true

sudo systemctl disable captive-flask-monitor.service 2>/dev/null || true
sudo systemctl stop captive-flask-monitor.service 2>/dev/null || true

# Dispatcher 파일 삭제
if [ -f "$DISPATCH_DIR/99-captive-flask" ]; then
    sudo rm "$DISPATCH_DIR/99-captive-flask"
    echo "[REMOVE] $DISPATCH_DIR/99-captive-flask"
fi

# Flask systemd 유닛 삭제
if [ -f "$SYSTEMD_DIR/captive-flask.service" ]; then
    sudo rm "$SYSTEMD_DIR/captive-flask.service"
    echo "[REMOVE] $SYSTEMD_DIR/captive-flask.service"
fi

# Monitor systemd 유닛 및 스크립트 삭제
if [ -f "$MONITOR_SERVICE" ]; then
    sudo rm "$MONITOR_SERVICE"
    echo "[REMOVE] $MONITOR_SERVICE"
fi

if [ -f "$MONITOR_SCRIPT" ]; then
    sudo rm "$MONITOR_SCRIPT"
    echo "[REMOVE] $MONITOR_SCRIPT"
fi

# 환경파일 삭제
if [ -f "$ENV_FILE" ]; then
    sudo rm "$ENV_FILE"
    echo "[REMOVE] $ENV_FILE"
fi

# systemd 리로드
sudo systemctl daemon-reload

echo "[INFO] Removing captive nmcli profile..."
# nmcli 연결 삭제
if nmcli connection show "$CAPTIVE_PROFILE" &>/dev/null; then
    sudo nmcli connection delete "$CAPTIVE_PROFILE"
    echo "[REMOVE] nmcli profile '$CAPTIVE_PROFILE'"
else
    echo "[INFO] nmcli profile '$CAPTIVE_PROFILE' not found, skipping."
fi

echo "[INFO] Uninstallation completed."
