"""Pick a pre-created single-display iPhone simulator running iOS 27+."""
import json
import re
import sys

# Skip the foldable iPhone Duo: its two displays break `simctl io screenshot`.
PREFERRED = ["iPhone 17", "iPhone 18 Pro", "iPhone 18 Pro Max", "iPhone Air", "iPhone 17e"]

with open(sys.argv[1], encoding="utf-8") as source:
    runtimes = json.load(source)["devices"]

available = {}  # device name -> (runtime version, udid); newest runtime wins
for runtime, devices in runtimes.items():
    version = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not version or int(version[1]) < 27:
        continue
    key = (int(version[1]), int(version[2]))
    for device in devices:
        name = device["name"]
        if device.get("isAvailable") and name.startswith("iPhone") and "Duo" not in name:
            if name not in available or key > available[name][0]:
                available[name] = (key, device["udid"])

if not available:
    sys.exit("No single-display iPhone simulator with iOS 27+. Install an iOS 27 runtime or change the runner image.")
for name in PREFERRED:
    if name in available:
        print("SIMULATOR_ID=" + available[name][1])
        break
else:
    print("SIMULATOR_ID=" + available[sorted(available)[0]][1])
