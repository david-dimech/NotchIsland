import CoreMIDI
import Foundation
import os.log

/// Lightweight CoreMIDI client that listens globally to every connected source
/// (USB, Thunderbolt, virtual network) and fires `onEvent` on the main thread
/// whenever a musically-relevant packet arrives.
///
/// Runs entirely on CoreMIDI's private callback thread — zero impact on the
/// main thread until a packet fires, at which point a single async dispatch
/// signals the UI layer.
final class MIDIManager {

    /// Called on the **main thread** for every Note-On/Off, CC, or Clock packet.
    var onEvent: (() -> Void)?

    private var client:    MIDIClientRef = 0
    private var inputPort: MIDIPortRef   = 0

    private let log = Logger(subsystem: "com.notchisland.app", category: "CoreMIDI")

    init() { setup() }

    deinit {
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client    != 0 { MIDIClientDispose(client)  }
    }

    // MARK: – Setup

    private func setup() {
        // Notification block — called when the MIDI graph changes (device plug/unplug).
        // Strong capture is fine here; MIDIManager outlives the client.
        let notifyBlock: MIDINotifyBlock = { [weak self] ptr in
            switch ptr.pointee.messageID {
            case .msgSetupChanged, .msgObjectAdded:
                DispatchQueue.main.async { [weak self] in self?.connectAllSources() }
            default:
                break
            }
        }

        var status = MIDIClientCreateWithBlock(
            "com.notchisland.MIDIClient" as CFString,
            &client,
            notifyBlock
        )
        guard status == noErr else {
            log.error("MIDIClientCreateWithBlock → \(status)")
            return
        }

        // Receive block — executed on CoreMIDI's internal thread (not main).
        let receiveBlock: MIDIReadBlock = { [weak self] packetListPtr, _ in
            self?.handlePacketList(packetListPtr)
        }

        status = MIDIInputPortCreateWithBlock(
            client,
            "com.notchisland.InputPort" as CFString,
            &inputPort,
            receiveBlock
        )
        guard status == noErr else {
            log.error("MIDIInputPortCreateWithBlock → \(status)")
            return
        }

        connectAllSources()
    }

    // MARK: – Source binding

    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }
            let s = MIDIPortConnectSource(inputPort, src, nil)
            // –50 (paramErr) means already connected — that is fine.
            if s != noErr, s != -50 {
                log.warning("MIDIPortConnectSource[\(i)] → \(s)")
            }
        }
        if count > 0 { log.info("Bound to \(count) MIDI source(s)") }
    }

    // MARK: – Packet parsing (CoreMIDI callback thread)

    private func handlePacketList(_ listPtr: UnsafePointer<MIDIPacketList>) {
        let n = Int(listPtr.pointee.numPackets)
        guard n > 0 else { return }

        // Standard Apple pattern: walk packets using MIDIPacketNext, but guard
        // against calling it past the last valid packet.
        var packet = listPtr.pointee.packet
        for i in 0..<n {
            if shouldFire(packet: &packet) {
                DispatchQueue.main.async { [weak self] in self?.onEvent?() }
                return  // one dispatch per packet-list is enough to flash the UI
            }
            if i + 1 < n { packet = MIDIPacketNext(&packet).pointee }
        }
    }

    private func shouldFire(packet: inout MIDIPacket) -> Bool {
        guard packet.length > 0 else { return false }

        // Access the fixed 256-byte data tuple through raw bytes — safe because
        // we only ever read up to packet.length which is ≤ 256.
        return withUnsafeBytes(of: packet.data) { raw -> Bool in
            guard let status = raw.first else { return false }
            switch status {
            case 0xF8:                    // MIDI Clock (24 ppq)
                return true
            case 0x80...0x8F:            // Note Off
                return true
            case 0x90...0x9F:            // Note On — ignore velocity-0 (== Note Off)
                let vel: UInt8 = packet.length >= 3 ? raw[2] : 0
                return vel > 0
            case 0xB0...0xBF:            // Control Change
                return true
            default:
                return false
            }
        }
    }
}
