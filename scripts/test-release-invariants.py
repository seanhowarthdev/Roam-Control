#!/usr/bin/env python3
"""Check Build 61 release, scheduler and telemetry invariants without networking."""

from pathlib import Path
import plistlib
import re
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def function_body(source: str, signature: str) -> str:
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return source[opening : index + 1]
    raise AssertionError(f"Unterminated function: {signature}")


project = (ROOT / "RoamControl.xcodeproj/project.pbxproj").read_text()
assert project.count("CURRENT_PROJECT_VERSION = 61;") == 4
assert project.count("MARKETING_VERSION = 0.9.2;") == 4

with (ROOT / "Configuration/RoamControl-Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
assert not any("Telemetry" in key for key in info)
assert info["CFBundleDisplayName"] == "Cat Go"
assert info["CFBundleName"] == "Cat Go"
assert info["CFBundleIdentifier"] == "$(PRODUCT_BUNDLE_IDENTIFIER)"
assert info["CFBundleURLTypes"][0]["CFBundleURLSchemes"] == ["roamcontrol"]
public_config = (ROOT / "Configuration/Local.xcconfig").read_text()
assert "ROAMCONTROL_APP_BUNDLE_IDENTIFIER = com.sean.roamcontrol" in public_config
assert "TELEMETRY" not in public_config
analytics = (ROOT / "RoamControl/Services/UsageAnalyticsService.swift").read_text()
assert "URLSession" not in analytics
assert "URLRequest" not in analytics
assert "https://" not in analytics
assert "anonymousUsageIdentifier" in function_body(analytics, "func revokeLocalIdentity()")
settings = (ROOT / "RoamControl/Features/Settings/SettingsView.swift").read_text()
onboarding = (ROOT / "RoamControl/Features/Onboarding/OnboardingView.swift").read_text()
for source in (settings, onboarding):
    assert "Share Anonymous Usage Statistics" not in source
    assert "seanhowarth" not in source
assert "checkForUpdates" not in settings
assert not (ROOT / "RoamControl/Services/ReleaseUpdateChecker.swift").exists()

session = (ROOT / "RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift").read_text()
submission = function_body(session, "private func observeLocationScheduler()")
assert "BackgroundTaskIdentifier.configurationStatus(for: \"location\")" in submission
assert "guard taskConfigurationStatus == .permitted," in submission
assert "submitTaskRequest" not in session
assert "runNativeLocationSession()" in function_body(session, "private func submitLocationTask()")

pairing = (ROOT / "RoamControl/Services/Pairing/OnDevicePairingCoordinator.swift").read_text()
assert "taskConfigurationStatus: BackgroundTaskConfigurationStatus = .notChecked" in pairing
assert "taskRegistrationStatus: BackgroundTaskRegistrationStatus = .notAttempted" in pairing
assert "taskConfigurationStatus = BackgroundTaskIdentifier.configurationStatus(for: \"pairing\")" in pairing
assert "taskRegistrationStatus = wasRegistered ? .accepted : .rejected" not in pairing
assert "runNativePairing()" in pairing[pairing.index('func start('):pairing.index('func cancel(')]
assert "BGTaskScheduler.shared" not in pairing

app_model = (ROOT / "RoamControl/App/AppModel.swift").read_text()
assert "onDevicePairing.onFailure = { [weak self] diagnostic in" in app_model
assert "self.onDevicePairing.taskConfigurationStatus" not in app_model
assert "self.deviceSession.taskConfigurationStatus" not in app_model

diagnostics = (ROOT / "RoamControl/Features/Settings/ConnectionHealthView.swift").read_text()
assert "Location task configuration:" in diagnostics
assert "Location task registration:" in diagnostics
assert "Pairing task configuration:" in diagnostics
assert "Pairing task registration:" in diagnostics

private_config = ROOT / "Configuration/Local.private.xcconfig"
if private_config.exists():
    match = re.search(
        r"^ROAMCONTROL_SELFHOSTED_TELEMETRY_TOKEN\s*=\s*(\S+)\s*$",
        private_config.read_text(),
        re.MULTILINE,
    )
    if match and match.group(1):
        token = match.group(1)
        tracked = subprocess.check_output(
            ["git", "ls-files", "-z"], cwd=ROOT
        ).decode().split("\0")
        for relative in filter(None, tracked):
            path = ROOT / relative
            if path.is_file():
                assert token not in path.read_text(errors="ignore"), f"Private token tracked in {relative}"

print("Build 61 release, scheduler and disabled-statistics source checks passed; no network requests made.")
