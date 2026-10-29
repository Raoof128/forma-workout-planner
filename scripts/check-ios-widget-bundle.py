"""Validate the actual embedded extension, privacy manifest and signed group boundary."""

import json
import pathlib
import plistlib
import re
import subprocess
import sys
from xml.parsers.expat import ExpatError


def read_plist(path):
    with path.open("rb") as handle:
        return plistlib.load(handle)


def entitlements(bundle):
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        check=True, capture_output=True,
    )
    signed = plistlib.loads(result.stdout)
    if "com.apple.security.application-groups" in signed:
        return signed
    info = read_plist(bundle / "Info.plist")
    executable = bundle / info["CFBundleExecutable"]
    platform = subprocess.run(
        ["xcrun", "vtool", "-show-build", str(executable)],
        check=True, capture_output=True, text=True,
    ).stdout
    if "IOSSIMULATOR" not in platform:
        raise ValueError("A device binary must carry real signed App Group entitlements")
    # Xcode stores simulated entitlements in a Mach-O section, not the ad-hoc signature.
    section = subprocess.run(
        ["otool", "-s", "__TEXT", "__entitlements", str(executable)],
        check=True, capture_output=True, text=True,
    ).stdout
    data = bytearray()
    for line in section.splitlines():
        words = line.split()
        if words and re.fullmatch(r"[0-9a-f]{16}", words[0]):
            for word in words[1:]:
                if re.fullmatch(r"(?:[0-9a-f]{2}){1,4}", word):
                    data.extend(bytes.fromhex(word)[::-1])
    return plistlib.loads(bytes(data).rstrip(b"\x00"))


SOURCES = pathlib.Path(__file__).resolve().parent.parent / "ios"
FAMILIES = {
    "systemSmall", "systemMedium", "systemLarge",
    "accessoryCircular", "accessoryRectangular", "accessoryInline",
}


def source(relative):
    return (SOURCES / relative).read_text(encoding="utf-8")


def check_link_contract(app_info):
    """Widget taps are `forma://widget/...` links: they die silently if the scheme drifts."""
    schemes = {
        scheme
        for entry in app_info.get("CFBundleURLTypes", [])
        for scheme in entry.get("CFBundleURLSchemes", [])
    }
    route = source("Sources/FORMASurfaces/WidgetRoute.swift")
    emitted = re.findall(r'components\.scheme = "([^"]+)"', route)
    parsed = re.findall(r'parts\.scheme == "([^"]+)"', route)
    host = re.findall(r'components\.host = "([^"]+)"', route)
    assert emitted == ["forma"] and parsed == ["forma"], "WidgetRoute must emit and accept forma://"
    assert host == ["widget"], "WidgetRoute host changed; update the app URL handling together"
    assert emitted[0] in schemes, "App Info.plist CFBundleURLTypes no longer registers forma://"


def check_widget_declaration(widget_info):
    """TrainingWidget keeps its six families and one kind; the bundle adds the workout Live Activity."""
    declaration = source("FORMAWidgets/TrainingWidget.swift")
    block = re.search(r"supportedFamilies\(\[(.*?)\]\)", declaration, re.DOTALL)
    assert block, "TrainingWidget no longer declares supportedFamilies"
    families = set(re.findall(r"\.(system\w+|accessory\w+)", block.group(1)))
    assert families == FAMILIES, f"Supported widget families changed: {sorted(families)}"
    assert len(re.findall(r"AppIntentConfiguration\(", declaration)) == 1, "TrainingWidget has one kind"
    assert "@main" not in declaration, "@main moved to the WidgetBundle; TrainingWidget must not have it"
    kind = re.search(
        r'static let kind = "([^"]+)"', source("Sources/FORMASurfaces/TrainingSnapshot.swift"))
    assert kind and kind.group(1) == "dev.raoufabedini.forma.training", "Widget kind changed"
    # NSSupportsLiveActivities belongs to the host app (checked in `check_live_activity`), not the extension.
    assert "NSSupportsLiveActivities" not in widget_info


def check_live_activity(app_info):
    """The extension now intentionally holds one workout Live Activity, local only and bundled."""
    assert app_info.get("NSSupportsLiveActivities") is True, (
        "The app Info.plist must set NSSupportsLiveActivities to true"
    )
    # Frequent updates and push stay out: there is no server, and the app sends nothing per second.
    assert "NSSupportsLiveActivitiesFrequentUpdates" not in app_info
    bundle = source("FORMAWidgets/FORMAWidgetBundle.swift")
    assert re.search(r":\s*WidgetBundle\b", bundle), "The extension no longer declares a WidgetBundle"
    assert len(re.findall(r"@main\b", bundle)) == 1, "Exactly one @main entry point is expected"
    for name in ("TrainingWidget()", "WorkoutLiveActivity()"):
        assert name in bundle, f"The widget bundle no longer lists {name}"
    for path in pathlib.Path(SOURCES, "FORMAWidgets").glob("*.swift"):
        if path.name != "FORMAWidgetBundle.swift":
            assert "@main" not in path.read_text(encoding="utf-8"), f"{path.name} must not declare @main"
    live = source("FORMAWidgets/WorkoutLiveActivity.swift")
    assert "ActivityConfiguration(for: WorkoutActivityAttributes.self)" in live
    # iOS 18 only: the compact family must stay behind an availability check on a 17.0 target.
    assert re.search(r"@available\(iOS 18\.0, \*\)\s*struct WorkoutLiveActivityWithSmallFamily", live)
    assert live.count("supplementalActivityFamilies") == 2  # the doc comment and the one call
    # The app starts activities locally: no push token, and none of the newer-than-26.2 symbols.
    controller = source("FORMA/App/WorkoutLiveActivityController.swift")
    assert "pushType: nil" in controller, "Live Activities must be local only (no push)"
    for folder in ("WidgetPresentation", "FORMAWidgets", "FORMA/App"):
        for file in (SOURCES / folder).glob("*.swift"):
            text = file.read_text(encoding="utf-8")
            assert "isDynamicIslandLimitedInWidth" not in text, (
                f"{file.name} uses an iOS 27 symbol; CI builds with the iOS 26.2 SDK"
            )


def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: python3 scripts/check-ios-widget-bundle.py /path/FORMA.app")
    app = pathlib.Path(sys.argv[1])
    widget = app / "PlugIns/FORMAWidgets.appex"
    info = read_plist(widget / "Info.plist")
    assert info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension"
    assert info["MinimumOSVersion"] == "17.0"
    check_link_contract(read_plist(app / "Info.plist"))
    check_widget_declaration(info)
    check_live_activity(read_plist(app / "Info.plist"))
    group = "group.dev.raoufabedini.forma"
    assert group in entitlements(app)["com.apple.security.application-groups"]
    signed = entitlements(widget)
    assert signed["com.apple.security.application-groups"] == [group]
    assert signed["com.apple.developer.default-data-protection"] == "NSFileProtectionComplete"
    assert "com.apple.developer.healthkit" not in signed
    privacy = read_plist(widget / "PrivacyInfo.xcprivacy")
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
    assert privacy["NSPrivacyAccessedAPITypes"] == []
    links = subprocess.run(
        ["otool", "-L", str(widget / info["CFBundleExecutable"])],
        check=True, capture_output=True, text=True,
    ).stdout
    assert "libsqlite3" not in links and "HealthKit.framework" not in links
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print(json.dumps({"extension": info["CFBundleIdentifier"], "minimum_iOS": "17.0",
                      "protected_group": True, "no_database_or_health_link": True,
                      "embedded_signature": "verified", "link_scheme": "forma",
                      "families": sorted(FAMILIES), "live_activity": "local, bundled"}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, AssertionError, ExpatError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Widget bundle validation failed: {error}") from error
