"""Validate the two embedded widget extensions, their privacy manifests and signed boundaries.

`FORMAWidgets.appex` holds the Training widget: App Group, Complete data protection.
`FORMAWorkoutActivity.appex` holds the workout Live Activity: no App Group, no data protection,
so the lock that hides the widget's data cannot hide the workout card (audit 2026-11-02 H2).
"""

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


def entitlements(bundle, expects_group=True):
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        check=True, capture_output=True,
    )
    signed = plistlib.loads(result.stdout) if result.stdout.strip() else {}
    if "com.apple.security.application-groups" in signed:
        return signed
    if not expects_group and "application-identifier" in signed:
        # A signed device extension that asks for nothing beyond its own identity.
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
    """TrainingWidget keeps its six families and one kind; no extension declares Live Activity support."""
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


def check_single_main(folder, bundle_file):
    for path in pathlib.Path(SOURCES, folder).glob("*.swift"):
        if path.name != bundle_file:
            assert "@main" not in path.read_text(encoding="utf-8"), f"{path.name} must not declare @main"


def check_live_activity(app_info):
    """The workout Live Activity lives in its own extension, local only, and taps open the workout."""
    assert app_info.get("NSSupportsLiveActivities") is True, (
        "The app Info.plist must set NSSupportsLiveActivities to true"
    )
    # Frequent updates and push stay out: there is no server, and the app sends nothing per second.
    assert "NSSupportsLiveActivitiesFrequentUpdates" not in app_info
    training = source("FORMAWidgets/FORMAWidgetBundle.swift")
    assert re.search(r":\s*WidgetBundle\b", training), "The widget extension no longer declares a WidgetBundle"
    assert len(re.findall(r"@main\b", training)) == 1, "Exactly one @main entry point is expected"
    assert "TrainingWidget()" in training, "The widget bundle no longer lists TrainingWidget()"
    assert "WorkoutLiveActivity" not in training, (
        "The Live Activity must stay out of the Complete-protected widget extension"
    )
    check_single_main("FORMAWidgets", "FORMAWidgetBundle.swift")
    assert not list(pathlib.Path(SOURCES, "FORMAWidgets").glob("WorkoutLiveActivity*.swift"))

    bundle = source("FORMAWorkoutActivity/WorkoutActivityBundle.swift")
    assert re.search(r":\s*WidgetBundle\b", bundle), "The activity extension no longer declares a WidgetBundle"
    assert len(re.findall(r"@main\b", bundle)) == 1, "Exactly one @main entry point is expected"
    for name in ("WorkoutLiveActivity()", "WorkoutLiveActivityWithSmallFamily()"):
        assert name in bundle, f"The activity bundle no longer lists {name}"
    assert "TrainingWidget" not in bundle, "The Training widget must stay in its protected extension"
    check_single_main("FORMAWorkoutActivity", "WorkoutActivityBundle.swift")
    live = source("FORMAWorkoutActivity/WorkoutLiveActivity.swift")
    assert "ActivityConfiguration(for: WorkoutActivityAttributes.self)" in live
    # iOS 18 only: the compact family must stay behind an availability check on a 17.0 target.
    assert re.search(r"@available\(iOS 18\.0, \*\)\s*struct WorkoutLiveActivityWithSmallFamily", live)
    assert live.count("supplementalActivityFamilies") == 2  # the doc comment and the one call
    # One link per hierarchy (Lock Screen root and Dynamic Island), to the workout route that the
    # app checks against the active session and owner, not the widget-sharing `active` route.
    assert live.count(".widgetURL(workoutLink(context.attributes))") == 2, (
        "Both Live Activity hierarchies must link to the workout"
    )
    assert "WidgetRoute.workout(id: attributes.sessionID, epoch: attributes.ownerEpoch)" in live
    route = source("Sources/FORMASurfaces/WidgetRoute.swift")
    assert 'components.path = "/workout"' in route and '"/workout"' in route.split("init?(url")[1]
    routing = source("FORMA/App/AppModel+WidgetRouting.swift")
    assert "case .workout(let id, let epoch):" in routing, "The app no longer routes the workout link"
    # The activity extension reads nothing: no App Group container, no snapshot file.
    for folder in ("FORMAWorkoutActivity",):
        for file in (SOURCES / folder).glob("*.swift"):
            text = file.read_text(encoding="utf-8")
            for word in ("containerURL", "TrainingSnapshot", "UserDefaults(suiteName"):
                assert word not in text, f"{file.name} reads storage ({word}); the extension must not"
    # The app starts activities locally: no push token.
    controller = source("FORMA/App/WorkoutLiveActivityController.swift")
    assert "pushType: nil" in controller, "Live Activities must be local only (no push)"
    # iOS 27 symbols only behind the compiler gate, so the iOS 26.2 SDK in CI still builds.
    for folder in ("WidgetPresentation", "FORMAWidgets", "FORMAWorkoutActivity", "FORMA/App"):
        for file in (SOURCES / folder).glob("*.swift"):
            text = file.read_text(encoding="utf-8")
            if "isDynamicIslandLimitedInWidth" not in text:
                continue
            gated = "".join(re.findall(r"#if compiler\(>=6\.4\)(.*?)#endif", text, re.DOTALL))
            outside = text.count("isDynamicIslandLimitedInWidth") - gated.count(
                "isDynamicIslandLimitedInWidth")
            assert outside == 0, (
                f"{file.name} uses an iOS 27 symbol outside `#if compiler(>=6.4)`; CI uses the iOS 26.2 SDK"
            )


def check_extension(appex):
    """Shared checks: a WidgetKit extension on the 17.0 floor, an empty privacy manifest, and no
    database or Health linkage."""
    info = read_plist(appex / "Info.plist")
    assert info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension"
    assert info["MinimumOSVersion"] == "17.0"
    privacy = read_plist(appex / "PrivacyInfo.xcprivacy")
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
    assert privacy["NSPrivacyAccessedAPITypes"] == []
    links = subprocess.run(
        ["otool", "-L", str(appex / info["CFBundleExecutable"])],
        check=True, capture_output=True, text=True,
    ).stdout
    assert "libsqlite3" not in links and "HealthKit.framework" not in links
    return info


def main():
    if len(sys.argv) != 2:
        raise ValueError("Usage: python3 scripts/check-ios-widget-bundle.py /path/FORMA.app")
    app = pathlib.Path(sys.argv[1])
    widget = app / "PlugIns/FORMAWidgets.appex"
    activity = app / "PlugIns/FORMAWorkoutActivity.appex"
    info = check_extension(widget)
    activity_info = check_extension(activity)
    assert info["CFBundleIdentifier"] == "dev.raoufabedini.forma.widgets"
    assert activity_info["CFBundleIdentifier"] == "dev.raoufabedini.forma.workoutactivity"
    check_link_contract(read_plist(app / "Info.plist"))
    check_widget_declaration(info)
    check_widget_declaration(activity_info)
    check_live_activity(read_plist(app / "Info.plist"))
    group = "group.dev.raoufabedini.forma"
    assert group in entitlements(app)["com.apple.security.application-groups"]
    signed = entitlements(widget)
    assert signed["com.apple.security.application-groups"] == [group]
    assert signed["com.apple.developer.default-data-protection"] == "NSFileProtectionComplete"
    assert "com.apple.developer.healthkit" not in signed
    # The Live Activity must run while the iPhone is locked: no Complete protection, and with no
    # App Group it cannot read the widget's snapshot even if code to do so were added.
    activity_signed = entitlements(activity, expects_group=False)
    for key in (
        "com.apple.security.application-groups",
        "com.apple.developer.default-data-protection",
        "com.apple.developer.healthkit",
    ):
        assert key not in activity_signed, f"The Live Activity extension must not carry {key}"
    subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    print(json.dumps({"extensions": [info["CFBundleIdentifier"], activity_info["CFBundleIdentifier"]],
                      "minimum_iOS": "17.0", "protected_group": "widgets only",
                      "live_activity_unprotected": True, "no_database_or_health_link": True,
                      "embedded_signature": "verified", "link_scheme": "forma",
                      "families": sorted(FAMILIES), "live_activity": "local, own extension, linked"},
                     indent=2))


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, KeyError, AssertionError, ExpatError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Widget bundle validation failed: {error}") from error
