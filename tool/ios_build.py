"""Verify unsigned iOS bundles and smoke-test a hosted iPhone Simulator."""

import argparse
import json
from pathlib import Path
import plistlib
import re
import subprocess
import time


BUNDLE_ID = "io.github.peter7004.recall"


def verify_bundle(app, platform, version):
    with (app / "Info.plist").open("rb") as source:
        info = plistlib.load(source)
    name, separator, number = version.partition("+")
    if not separator or not number.isdecimal():
        raise ValueError("Expected a pubspec version with a numeric build number")
    expected = {
        "CFBundleIdentifier": BUNDLE_ID,
        "CFBundleDisplayName": "Recall",
        "CFBundleShortVersionString": name,
        "CFBundleVersion": number,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            raise ValueError(f"Unexpected {key}: {info.get(key)!r}")
    if info.get("CFBundleSupportedPlatforms") != [platform]:
        raise ValueError("Unexpected bundle platform")
    if info.get("MinimumOSVersion") != "15.0":
        raise ValueError("Expected minimum iOS 15.0")
    for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"):
        if not isinstance(info.get(key), str) or not info[key].strip():
            raise ValueError(f"Missing permission description: {key}")
    for relative in (
        info.get("CFBundleExecutable", "Runner"),
        "Frameworks/Flutter.framework/Flutter",
        "Frameworks/App.framework/flutter_assets/web/branding/recall-logo.png",
    ):
        if not (app / relative).is_file():
            raise ValueError(f"Missing build output: {relative}")
    if platform == "iPhoneOS":
        sdk = re.fullmatch(r"iphoneos(\d+)\.\d+(?:\.\d+)?", info.get("DTSDKName", ""))
        if not sdk or int(sdk[1]) < 26:
            raise ValueError("The device archive requires iOS SDK 26 or newer")
        if (app / "_CodeSignature").exists():
            raise ValueError("Expected an unsigned device archive")
    return {
        **expected,
        "platform": platform,
        "minimum_ios": info["MinimumOSVersion"],
        "sdk": info.get("DTSDKName"),
        "privacy_manifests": sorted(str(p.relative_to(app)) for p in app.rglob("PrivacyInfo.xcprivacy")),
        "distribution_ready": False,
        "note": "Validation only. Apple distribution signing is still required.",
    }


def choose_iphone(devices):
    candidates = []
    for runtime, group in devices.items():
        match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+)-(\d+)(?:-(\d+))?", runtime)
        if not match:
            continue
        version = tuple(int(part or 0) for part in match.groups())
        for device in group:
            if device.get("isAvailable") and device.get("name", "").startswith("iPhone"):
                candidates.append((version, device["name"], device["udid"], device))
    if not candidates:
        raise ValueError("No available iPhone Simulator runtime")
    return max(candidates, key=lambda item: item[:3])[3]


def run(*arguments, timeout=120):
    return subprocess.run(arguments, check=True, text=True, capture_output=True, timeout=timeout).stdout


def smoke(app, output):
    output.mkdir(parents=True, exist_ok=True)
    devices = json.loads(run("xcrun", "simctl", "list", "devices", "available", "--json"))["devices"]
    device = choose_iphone(devices)
    udid = device["udid"]
    booted_here = device["state"] != "Booted"
    try:
        if booted_here:
            run("xcrun", "simctl", "boot", udid)
        run("xcrun", "simctl", "bootstatus", udid, "-b", timeout=300)
        run("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100")
        run("xcrun", "simctl", "install", udid, str(app.resolve()))
        launched = run("xcrun", "simctl", "launch", "--terminate-running-process", udid, BUNDLE_ID)
        match = re.search(r":\s*(\d+)\s*$", launched)
        if not match:
            raise ValueError("Simulator did not return an app process ID")
        pid = match[1]
        # Allow the first Flutter frame and the finite startup animation to finish.
        time.sleep(12)
        processes = run("xcrun", "simctl", "spawn", udid, "launchctl", "list")
        if not any(line.split()[:1] == [pid] and BUNDLE_ID in line for line in processes.splitlines()):
            raise ValueError("The app exited after launching")
        run("xcrun", "simctl", "io", udid, "screenshot", str(output / "iphone-home.png"))
        (output / "simulator-smoke.json").write_text(json.dumps({
            "device": device["name"], "udid": udid, "bundle_id": BUNDLE_ID,
            "process_id": int(pid), "alive_after_seconds": 12,
            "scope": "Launch smoke test; not a physical-device or interaction test",
        }, indent=2) + "\n", encoding="utf-8")
        print(f"Launched {BUNDLE_ID} on {device['name']} (PID {pid})")
    finally:
        if booted_here:
            subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, timeout=60)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("app", type=Path)
    verify.add_argument("--platform", choices=("iPhoneOS", "iPhoneSimulator"), required=True)
    verify.add_argument("--version", required=True)
    verify.add_argument("--report", type=Path, required=True)
    launch = commands.add_parser("smoke")
    launch.add_argument("app", type=Path)
    launch.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "verify":
        report = verify_bundle(args.app, args.platform, args.version)
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(report, indent=2))
    else:
        smoke(args.app, args.output)


if __name__ == "__main__":
    main()
