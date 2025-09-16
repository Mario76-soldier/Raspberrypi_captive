#!/bin/bash
TARGET_IF="wlan0"
FLASK_SERVICE="captive-flask.service"
AP_PROFILE="captive"

DISCONNECT_COUNT=0
THRESHOLD=10  # 초 단위

PREV_CONN=""

while true; do
    CUR_CONN=$(nmcli -t -f GENERAL.CONNECTION device show "$TARGET_IF" | cut -d: -f2)

    if [ "$CUR_CONN" = "$AP_PROFILE" ]; then
        # AP 모드 → 즉시 서비스 유지
        systemctl is-active --quiet "$FLASK_SERVICE" || systemctl restart "$FLASK_SERVICE"
        DISCONNECT_COUNT=0
    elif [ -z "$CUR_CONN" ] || [ "$CUR_CONN" = "--" ]; then
        # 연결 없음 → 카운트 시작
        ((DISCONNECT_COUNT+=1))
        if [ $DISCONNECT_COUNT -ge $THRESHOLD ]; then
            systemctl is-active --quiet "$FLASK_SERVICE" || systemctl restart "$FLASK_SERVICE"
        fi
    else
        # 일반 Wi-Fi 연결 → 서비스 중지
        systemctl is-active --quiet "$FLASK_SERVICE" && systemctl stop "$FLASK_SERVICE"
        DISCONNECT_COUNT=0
    fi

    sleep 1
done
