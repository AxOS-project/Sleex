#!/usr/bin/env python3
import subprocess
import json
import os
import getpass

# Path to the settings JSON
CONFIG_FILE = os.path.expanduser("~/.sleex/settings.json")

def run_cmd(cmd, capture_output=True):
    """Run a shell command and return its output."""
    result = subprocess.run(cmd, shell=True, text=True,
                            capture_output=capture_output)
    if result.returncode != 0:
        return None
    return result.stdout.strip()

def get_custom_dns():
    """Read customDNS from settings.json."""
    if not os.path.exists(CONFIG_FILE):
        print(f"Settings file not found: {CONFIG_FILE}")
        return None
    try:
        with open(CONFIG_FILE, "r") as f:
            config = json.load(f)
        # Navigate to dashboard.customDNS
        dns = config.get("dashboard", {}).get("customDNS", "").strip()
        if dns:
            return dns
        else:
            print("customDNS is empty in settings.json")
            return None
    except Exception as e:
        print(f"Failed to read settings.json: {e}")
        return None

def main():
    dns_server = get_custom_dns()
    if not dns_server:
        print("Please set a custom DNS in ~/.sleex/settings.json under dashboard.customDNS")
        return

    # Detect the active connection
    active_conn_cmd = "nmcli -t -f NAME,DEVICE connection show --active | head -n1 | cut -d: -f1"
    active_conn = run_cmd(active_conn_cmd)
    if not active_conn:
        print("No active network connection found.")
        return

    print(f"Setting DNS {dns_server} for connection '{active_conn}'...")

    # Check connection type
    con_type_cmd = f"nmcli -g connection.type connection show '{active_conn}'"
    con_type = run_cmd(con_type_cmd)

    # If Wi-Fi, check for PSK
    if con_type == "wifi":
        psk_cmd = f"nmcli -g 802-11-wireless-security.psk connection show '{active_conn}'"
        psk = run_cmd(psk_cmd)
        if not psk:
            psk = getpass.getpass("Wi-Fi password not found. Please enter it: ")
            subprocess.run(f"nmcli connection modify '{active_conn}' wifi-sec.psk '{psk}'", shell=True)

    # Set the DNS and ignore auto DNS
    set_dns_cmd = f"nmcli connection modify '{active_conn}' ipv4.dns '{dns_server}' ipv4.ignore-auto-dns yes"
    if run_cmd(set_dns_cmd) is None:
        print(f"Failed to set DNS {dns_server} for connection '{active_conn}'.")
        return

    # Reactivate the connection
    subprocess.run(f"nmcli connection down '{active_conn}'", shell=True)
    subprocess.run(f"nmcli connection up '{active_conn}'", shell=True)

    print("DNS updated successfully.")
    subprocess.run("nmcli dev show | grep DNS", shell=True)

if __name__ == "__main__":
    main()
