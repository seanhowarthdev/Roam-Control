#!/usr/bin/env python3
"""Check conversion and the actual coordinate expressions sent over the FFI."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
coordinator = (ROOT / "RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift").read_text()
# Reproduce the current bug: both calls pass the map's raw GCJ-02 values.
assert "rc_location_session_update(activeSession, wgs84.latitude, wgs84.longitude)" in coordinator
assert "target.latitude,\n                                target.longitude," not in coordinator
assert "wgs84.latitude,\n                                wgs84.longitude," in coordinator
assert coordinator.count("WGS84CoordinateConverter.fromMap(") == 2

checks = r'''
// Independent reference pair: Tiananmen, WGS-84 -> GCJ-02.
let beijing = WGS84CoordinateConverter.fromMap(
    latitude: 39.91022649807321, longitude: 116.4037135824225)
precondition(abs(beijing.latitude - 39.908823) < 0.000001)
precondition(abs(beijing.longitude - 116.39747) < 0.000001)
// The selected GCJ point must not be injected unchanged.
precondition(abs(beijing.longitude - 116.4037135824225) > 0.005)
// Outside the conversion bounds, preserve the input exactly.
for (latitude, longitude) in [(51.5074, -0.1278), (40.7128, -74.0060),
                              (35.6762, 139.6503), (-33.8688, 151.2093),
                              (0.0, 0.0), (-90.0, -180.0), (90.0, 180.0)] {
    let converted = WGS84CoordinateConverter.fromMap(latitude: latitude, longitude: longitude)
    precondition(converted.latitude == latitude && converted.longitude == longitude)
}
let invalid = WGS84CoordinateConverter.fromMap(latitude: .nan, longitude: 116)
precondition(invalid.latitude.isNaN)
print("WGS-84 conversion reference, bounds and both FFI coordinate paths passed")
'''
with tempfile.TemporaryDirectory(prefix="roam-wgs84-") as directory:
    source = Path(directory) / "main.swift"
    source.write_text((ROOT / "RoamControl/Services/Tunnel/WGS84CoordinateConverter.swift").read_text() + checks)
    subprocess.run(["swift", str(source)], check=True)
