//
//  PacketTunnelProvider.swift
//  TunnelProv
//
//  Created by Stossy11 on 28/03/2025.
//

import NetworkExtension
#if DEBUG
import os.log
#endif

@inline(__always)
private func tunnelLog(_ message: @autoclosure () -> String) {
#if DEBUG
    os_log("[TunnelProv] %{public}@", type: .error, message())
#endif
}


class PacketTunnelProvider: NEPacketTunnelProvider {
    private var isRunning = false
    var tunnelIfaceIP: String = TunnelConstants.defaultIfaceIP
    var tunnelPeerIP: String = TunnelConstants.defaultPeerIP
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        if let options = options {
            for (key, val) in options {
                tunnelLog("startTunnel option \(key) = \(String(describing: val))")
            }
        } else {
            tunnelLog("startTunnel: options is nil")
        }
        
        let providerConfiguration =
            (protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration

        if let ifaceIp = options?[TunnelConstants.ifaceIPConfigurationKey] as? String
            ?? providerConfiguration?[TunnelConstants.ifaceIPConfigurationKey] as? String {
            tunnelLog("TunnelIfaceIP configured as: \(ifaceIp)")
            tunnelIfaceIP = ifaceIp
        }
        if let peerIp = options?[TunnelConstants.peerIPConfigurationKey] as? String
            ?? providerConfiguration?[TunnelConstants.peerIPConfigurationKey] as? String {
            tunnelLog("TunnelPeerIP configured as: \(peerIp)")
            tunnelPeerIP = peerIp
        }
        
        let ifaceEndpoint: CIDREndpoint
        let peerEndpoint: CIDREndpoint
        do {
            let pair = try CIDRValidator.shared.validatePair(
                tunnelIfaceInput: tunnelIfaceIP,
                tunnelPeerInput: tunnelPeerIP,
                allowIntermediateAddresses: TunnelConstants.defaultAllowIntermediateAddresses
            )
            ifaceEndpoint = pair.iface.endpoint
            peerEndpoint = pair.peer.endpoint
        } catch {
            completionHandler(error)
            return
        }
        
        tunnelLog("Configuring P2P settings: peer=\(peerEndpoint.ip)/\(peerEndpoint.prefix) (\(peerEndpoint.subnetMask)), iface=\(ifaceEndpoint.ip)/\(ifaceEndpoint.prefix) (\(ifaceEndpoint.subnetMask))")
        
        // tunnel iface configuration
        let ifaceIPv4 = NEIPv4Settings(addresses: [ifaceEndpoint.ip], subnetMasks: [ifaceEndpoint.subnetMask])
        let tunnelDestinationIPv4Routes = [
            // actual destination routes of this VPN tunnel
            NEIPv4Route(destinationAddress: peerEndpoint.ip, subnetMask: peerEndpoint.subnetMask)
        ]
        ifaceIPv4.includedRoutes = tunnelDestinationIPv4Routes
        ifaceIPv4.excludedRoutes = [.default()]

        // Tunneling config
        let settings = NEPacketTunnelNetworkSettings(
            // NOTE: 'tunnelRemoteAddress' is just for UI concerns and is not involved in routing
            tunnelRemoteAddress: peerEndpoint.ip
        )   
        settings.ipv4Settings = ifaceIPv4
        
        tunnelLog("Calling setTunnelNetworkSettings...")
        setTunnelNetworkSettings(settings) { error in
            if let error = error {
                tunnelLog("Failed to set settings: \(error.localizedDescription)")
                return completionHandler(error)
            }
            tunnelLog("Tunnel network settings set successfully. Starting packet loops.")
            self.isRunning = true
            self.setPackets()
            completionHandler(nil)
        }
    }
    
    func setPackets() {
        guard isRunning else { return }
        packetFlow.readPackets { [self] packets, protocols in
            guard isRunning else { return }
            var modified = packets
            
            for i in modified.indices where protocols[i].int32Value == AF_INET && modified[i].count >= 20 {
                modified[i] = LocalTunnelPacket.reflectIPv4(modified[i])
            }
            
            self.packetFlow.writePackets(modified, withProtocols: protocols)
            setPackets()
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        isRunning = false
        completionHandler()
    }
}
