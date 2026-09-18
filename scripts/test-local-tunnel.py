#!/usr/bin/env python3
"""Run the local tunnel's address and packet checks without a VPN or signing."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
checks = r'''
let pair = try CIDRValidator.shared.validatePair(
    tunnelIfaceInput: TunnelConstants.defaultIfaceIP,
    tunnelPeerInput: TunnelConstants.defaultPeerIP)
assert(pair.iface.ip == "10.7.1.1" && pair.peer.ip == "10.7.0.1")
assert(pair.iface.subnetMask == "255.255.255.255")
for (iface, peer) in [("999.7.1.1/32", "10.7.0.1/32"),
                      ("10.7.0.1/32", "10.7.0.1/32"),
                      ("10.7.1.1/33", "10.7.0.1/32")] {
    do {
        _ = try CIDRValidator.shared.validatePair(tunnelIfaceInput: iface, tunnelPeerInput: peer)
        fatalError("Invalid addresses accepted")
    } catch {}
}
let original = Data([0x45, 0, 0, 24, 0, 1, 0, 0, 64, 6, 0, 0,
                     10, 7, 1, 1, 10, 7, 0, 1, 1, 2, 3, 4])
let reflected = LocalTunnelPacket.reflectIPv4(original)
assert(reflected[12..<16] == original[16..<20])
assert(reflected[16..<20] == original[12..<16])
assert(reflected[0..<12] == original[0..<12])
assert(reflected[20..<24] == original[20..<24])
assert(LocalTunnelPacket.reflectIPv4(reflected) == original)
// Swapping addresses preserves both IPv4 and TCP pseudo-header checksum sums.
func sum(_ bytes: Data) -> UInt32 {
    stride(from: 0, to: bytes.count, by: 2).reduce(0) {
        $0 + (UInt32(bytes[$1]) << 8) + UInt32(bytes[$1 + 1])
    }
}
assert(sum(Data(original[0..<20])) == sum(Data(reflected[0..<20])))
assert(sum(Data(original[12..<20])) == sum(Data(reflected[12..<20])))
assert(LocalTunnelPacket.reflectIPv4(Data()) == Data())
assert(LocalTunnelPacket.reflectIPv4(Data(original.prefix(19))) == Data(original.prefix(19)))
var ipv6 = original
ipv6[0] = 0x60
assert(LocalTunnelPacket.reflectIPv4(ipv6) == ipv6)
print("Local tunnel CIDR validation, packet reflection and checksum invariants passed")
'''
sources = [ROOT / "TunnelShared" / name for name in
           ("CIDRValidator.swift", "Constants.swift", "LocalTunnelPacket.swift")]
with tempfile.TemporaryDirectory(prefix="roam-local-tunnel-") as directory:
    entry = Path(directory) / "main.swift"
    entry.write_text("\n".join(p.read_text() for p in sources) + checks)
    subprocess.run(["swift", str(entry)], check=True)
