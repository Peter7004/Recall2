import copy
from pathlib import Path
import plistlib
import tempfile
import unittest

from ios_build import BUNDLE_ID, choose_iphone, verify_bundle


class BundleVerificationTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.app = Path(self.temporary.name) / "Runner.app"
        self.app.mkdir()
        self.info = {
            "CFBundleIdentifier": BUNDLE_ID,
            "CFBundleDisplayName": "Recall",
            "CFBundleExecutable": "Runner",
            "CFBundleShortVersionString": "1.0.1",
            "CFBundleVersion": "2",
            "CFBundleSupportedPlatforms": ["iPhoneOS"],
            "MinimumOSVersion": "15.0",
            "DTSDKName": "iphoneos26.2",
            "NSCameraUsageDescription": "Study photos",
            "NSPhotoLibraryUsageDescription": "Choose a study photo",
        }
        self.logo = self.app / "Frameworks/App.framework/flutter_assets/web/branding/recall-logo.png"
        for path in (self.app / "Runner", self.app / "Frameworks/Flutter.framework/Flutter", self.logo):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b"fixture")

    def verify(self, platform="iPhoneOS"):
        with (self.app / "Info.plist").open("wb") as target:
            plistlib.dump(self.info, target)
        return verify_bundle(self.app, platform, "1.0.1+2")

    def test_unsigned_device_bundle(self):
        self.assertFalse(self.verify()["distribution_ready"])

    def test_simulator_bundle(self):
        self.info["CFBundleSupportedPlatforms"] = ["iPhoneSimulator"]
        self.assertEqual(self.verify("iPhoneSimulator")["platform"], "iPhoneSimulator")

    def test_invalid_identity_version_platform_and_permissions(self):
        original = copy.deepcopy(self.info)
        for key, value in (
            ("CFBundleIdentifier", "com.example.recall"),
            ("CFBundleVersion", "1"),
            ("CFBundleShortVersionString", "1.0.0"),
            ("CFBundleSupportedPlatforms", ["iPhoneSimulator"]),
            ("MinimumOSVersion", "13.0"),
            ("NSCameraUsageDescription", ""),
            ("NSPhotoLibraryUsageDescription", None),
            ("DTSDKName", "iphoneos18.5"),
        ):
            with self.subTest(key=key):
                self.info = {**original, key: value}
                if value is None:
                    del self.info[key]
                with self.assertRaises(ValueError):
                    self.verify()

    def test_missing_logo(self):
        self.logo.unlink()
        with self.assertRaises(ValueError):
            self.verify()

    def test_signed_archive_rejected(self):
        (self.app / "_CodeSignature").mkdir()
        with self.assertRaises(ValueError):
            self.verify()


class SimulatorSelectionTest(unittest.TestCase):
    def test_latest_available_iphone(self):
        devices = {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-5": [{"name": "iPhone 16", "udid": "old", "isAvailable": True}],
            "com.apple.CoreSimulator.SimRuntime.iOS-26-2": [
                {"name": "iPhone 17", "udid": "missing", "isAvailable": False},
                {"name": "iPad Pro", "udid": "tablet", "isAvailable": True},
                {"name": "iPhone 17 Pro", "udid": "new", "isAvailable": True},
            ],
            "com.apple.CoreSimulator.SimRuntime.tvOS-26-2": [{"name": "iPhone fake", "udid": "wrong", "isAvailable": True}],
        }
        self.assertEqual(choose_iphone(devices)["udid"], "new")

    def test_no_available_iphone(self):
        with self.assertRaises(ValueError):
            choose_iphone({})


if __name__ == "__main__":
    unittest.main()
