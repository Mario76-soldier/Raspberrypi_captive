from flask import Flask, request, redirect, render_template
import os, subprocess, threading, time

CONFIG_FILE="config.txt"

app = Flask(__name__)

def load_config():
    config = {}
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r", encoding="utf-8") as f:
            for line in f:
                if "=" in line:
                    k, v = line.strip().split("=", 1)
                    config[k] = v
    return config

def save_config_dict(config: dict):
    with open(CONFIG_FILE, "w", encoding="utf-8") as f:
        for k, v in config.items():
            f.write(f"{k}={v}\n")

def shutdown_later(delay: float = 2.0):
    def _shutdown():
        time.sleep(delay)
        print("Flask server shutting down...")
        os._exit(0)
    threading.Thread(target=_shutdown, daemon=True).start()

@app.route('/', defaults={'path': ''})
@app.route('/<path:path>')
def catch_all(path):
    return redirect("/portal", code=302)

@app.route('/portal')
def portal():
    wifi_list = []
    try:
        cmd = ["nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        for line in result.stdout.strip().split("\n"):
            if not line:
                continue
            ssid, signal, security = (line.split(":") + ["", "", ""])[:3]
            if ssid: 
                wifi_list.append({
                    "ssid": ssid,
                    "signal": signal,
                    "security": security
                })
        wifi_list.sort(key=lambda x: int(x["signal"]), reverse=True)
    except Exception as e:
        print("Wi-Fi scan error:", e)

    return render_template("portal.html", wifi_list=wifi_list)

@app.route('/save_wifi', methods=["POST"])
def save_wifi():
    ssid = request.form.get("ssid", "")
    password = request.form.get("pass", "")

    config = load_config()

    if ssid:
        config["ssid"] = ssid
    if password:
        config["password"] = password

    save_config_dict(config)

    return redirect("/config")

@app.route('/config')
def config():
    config=load_config()

    device_id=config["device_id"] if "device_id" in config else ""
    device_location=config["device_location"] if "device_location" in config else ""
    device_admin=config["device_admin"] if "device_admin" in config else ""

    return render_template('config.html', DEVICE_ID=device_id, DEVICE_LOCATION=device_location, DEVICE_ADMIN=device_admin)

@app.route('/save_config', methods=["POST"])
def save_config():
    device_location = request.form.get("device_location", "")
    device_admin = request.form.get("device_admin", "")

    config = load_config()

    if device_location:
        config["device_location"] = device_location
    if device_admin:
        config["device_admin"] = device_admin

    save_config_dict(config)

    return redirect("/complete")

@app.route('/complete')
def complete():
    config = load_config()
    ssid = config.get("ssid")
    password = config.get("password")
    wifi_status = "Wi-Fi Status: Not Attempted"
    success = False

    if ssid and password:
        try:
            subprocess.run(["nmcli", "device", "wifi", "connect", ssid, "password", password],
                           check=True)
            wifi_status = f"✅ Wi-Fi({ssid}) connected successfully"
            success = True
        except subprocess.CalledProcessError as e:
            wifi_status = f"❌ Failed to connect: {e}"
    elif ssid:
        try:
            subprocess.run(["nmcli", "device", "wifi", "connect", ssid],
                           check=True)
            wifi_status = f"✅ Wi-Fi({ssid}) connected successfully"
            success = True
        except subprocess.CalledProcessError as e:
            wifi_status = f"❌ Failed to connect: {e}"

    if success:
        shutdown_later(2.0)

    return render_template('complete.html', WIFI_STATUS=wifi_status)

if __name__ == "__main__":
    cmd = ["nmcli", "connection", "up", "captive"]
    result = subprocess.run(cmd, capture_output=True, text=True, check=True)
    app.run(host="0.0.0.0", port=80)