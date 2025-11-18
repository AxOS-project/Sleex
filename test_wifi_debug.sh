#!/bin/bash

# Test script to simulate wrong password scenarios
# This will help debug the NetworkManager behavior that our service should handle

echo "=== WiFi Wrong Password Debug Test ==="
echo

# Show current networks
echo "1. Available networks:"
nmcli device wifi list

echo
echo "2. Current device status:"
nmcli device status

echo 
echo "3. Testing connection scenarios..."

# We'll need to identify a secure network to test with
echo "Please manually identify a WPA/WPA2 network from the list above to test with."
echo "Then run: nmcli device wifi connect \"NETWORK_NAME\" password \"wrongpassword123\""
echo 
echo "Monitor the logs with: journalctl -u NetworkManager -f"
echo "And check our debug output when using the actual Sleex WiFi interface"