import Foundation

/// LocalDevVPN's IPv4 address reflection, using alignment-independent byte access.
enum LocalTunnelPacket {
    static func reflectIPv4(_ packet: Data) -> Data {
        guard packet.count >= 20, packet[packet.startIndex] >> 4 == 4 else { return packet }
        var reflected = Data(packet)
        let source = reflected.subdata(in: 12..<16)
        let destination = reflected.subdata(in: 16..<20)
        reflected.replaceSubrange(12..<16, with: destination)
        reflected.replaceSubrange(16..<20, with: source)
        return reflected
    }
}
