#!/usr/bin/env python3
import asyncio
import time
import requests
from datetime import datetime
from bleak import BleakScanner

TARGET_PREFIX = "00:25:DF"
TARGET_JACK ="F0:E8:F1"
# Update the URL with the actual URL to your PHP server endpoint.
SERVER_URL = ""

# Dictionary to track detected devices with the target prefix.
# Format: { "MAC": {"first_seen": timestamp, "last_seen": timestamp } }
tracked_devices = {}

SCAN_INTERVAL = 5.0   # seconds per scan
DEVICE_TIMEOUT = 10.0 # seconds without detection to consider a device "lost"

def get_gps_coordinates():
    """
    Simulate obtaining GPS coordinates.
    Replace this function with actual GPS interfacing code.
    For demonstration purposes, this returns fixed coordinates.
    """
    # Example: returning coordinates for location of Node

def send_alert(mac, duration, device_count, lat, lon):
    """Send an alert to the central server for a device that is no longer detected."""
    payload = {
        "mac": mac,
        "duration": duration,
        "timestamp": datetime.now().isoformat(),
        "lat": lat,
        "lon": lon,
        "device_count": device_count
    }
    try:
        response = requests.post(SERVER_URL, json=payload)
        print(f"Alert sent for {mac}: duration {duration:.2f}s, device_count {device_count}, response: {response.status_code}")
    except Exception as e:
        print(f"Error sending alert for {mac}: {e}")

async def scan_loop():
    global tracked_devices
    while True:
        print("Scanning for BLE devices...")
        # Perform an asynchronous scan for SCAN_INTERVAL seconds.
        devices = await BleakScanner.discover(timeout=SCAN_INTERVAL)
        current_time = time.time()

        # Count the number of devices with the target prefix in this scan.
        current_detected_count = sum(1 for dev in devices if dev.address.upper().startswith(TARGET_PREFIX))

        # Process devices found in the current scan.
        for dev in devices:
            mac = dev.address.upper()
            if mac.startswith(TARGET_PREFIX):
                if mac not in tracked_devices:
                    tracked_devices[mac] = {"first_seen": current_time, "last_seen": current_time}
                    print(f"New device detected: {mac}")
                else:
                    tracked_devices[mac]["last_seen"] = current_time
                    print(f"Device {mac} detected again.")

        # Check for devices that have timed out.
        to_remove = []
        for mac, times in tracked_devices.items():
            if current_time - times["last_seen"] > DEVICE_TIMEOUT:
                duration = times["last_seen"] - times["first_seen"]
                # Get GPS coordinates (e.g., from a GPS module)
                lat, lon = get_gps_coordinates()
                # Use the count from the current scan (or adjust as needed)
                device_count = current_detected_count
                print(f"Device {mac} lost (detected for {duration:.2f} seconds). Sending alert.")
                send_alert(mac, duration, device_count, lat, lon)
                to_remove.append(mac)

        # Remove devices that have been processed.
        for mac in to_remove:
            del tracked_devices[mac]

if __name__ == "__main__":
    asyncio.run(scan_loop())
