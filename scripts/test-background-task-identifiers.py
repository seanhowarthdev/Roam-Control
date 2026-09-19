#!/usr/bin/env python3
"""Compile the production identifier helper and exercise runtime/plist combinations."""
from pathlib import Path
import subprocess
import tempfile
import plistlib

root = Path(__file__).resolve().parents[1]
helper = root / 'RoamControl/Services/BackgroundTaskIdentifier.swift'
checks = r'''
import Foundation
for component in ["pairing", "location"] {
    for runtime in ["com.catgo.app", "com.catgo.app.U687363PJS"] {
        let prefix = runtime + "." + component
        precondition(BackgroundTaskIdentifier.prefix(for: component, bundleIdentifier: runtime) == prefix)
        let exact = prefix + ".*"
        let invalid = ["*", runtime + ".*", prefix + ".UUID", prefix + ".nested.*",
                       runtime + ".R9673G3XNB." + component + ".*", "unrelated." + component + ".*"]
        for entries in invalid.map({ [$0] }) + [invalid] {
            precondition(BackgroundTaskIdentifier.configurationStatus(for: component, bundleIdentifier: runtime, permittedIdentifiers: entries) == .runtimeIdentifierNotPermitted)
        }
        for entries in [[exact], invalid + [exact], [exact] + invalid] {
            precondition(BackgroundTaskIdentifier.configurationStatus(for: component, bundleIdentifier: runtime, permittedIdentifiers: entries) == .permitted)
        }
        for entries: [String]? in [nil, []] {
            precondition(BackgroundTaskIdentifier.configurationStatus(for: component, bundleIdentifier: runtime, permittedIdentifiers: entries) == .missingPermittedIdentifiers)
        }
    }
    for runtime: String? in [nil, ""] {
        precondition(BackgroundTaskIdentifier.prefix(for: component, bundleIdentifier: runtime) == nil)
        precondition(BackgroundTaskIdentifier.configurationStatus(for: component, bundleIdentifier: runtime, permittedIdentifiers: ["com.catgo.app." + component + ".*"]) == .missingRuntimeBundleIdentifier)
    }
    precondition(BackgroundTaskIdentifier.configurationStatus(for: component, bundleIdentifier: "com.catgo.app.U687363PJS", permittedIdentifiers: ["com.catgo.app." + component + ".*", "com.catgo.app.R9673G3XNB." + component + ".*"]) == .runtimeIdentifierNotPermitted)
}
print("Runtime identifier truth-table checks passed")
'''
with tempfile.TemporaryDirectory() as temp:
    source = Path(temp) / 'main.swift'
    source.write_text(checks)
    binary = Path(temp) / 'check'
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(temp) / 'cache'), str(helper), str(source), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
for component, file in [('pairing', 'Pairing/OnDevicePairingCoordinator.swift'), ('location', 'Tunnel/LocalDeviceSessionCoordinator.swift')]:
    source = (root / 'RoamControl/Services' / file).read_text()
    check = source.index(f'configurationStatus(for: "{component}")')
    if component == 'pairing':
        assert 'BGTaskScheduler.shared' not in source
        assert 'runNativePairing()' in source[check:]
    else:
        guard = source.index('guard taskConfigurationStatus == .permitted,', check)
        registration = source.index('BGTaskScheduler.shared.register(', check)
        assert check < guard < registration
        assert 'return' in source[guard:registration]
        assert f'let prefix = BackgroundTaskIdentifier.prefix(for: "{component}")' in source[guard:registration]
        assert 'submitTaskRequest' not in source
info = plistlib.loads((root / 'Configuration/RoamControl-Info.plist').read_bytes())
assert info['BGTaskSchedulerPermittedIdentifiers'] == ['$(PRODUCT_BUNDLE_IDENTIFIER).pairing.*', '$(PRODUCT_BUNDLE_IDENTIFIER).location.*']
print('Pairing/location pre-registration and plist invariants passed')
