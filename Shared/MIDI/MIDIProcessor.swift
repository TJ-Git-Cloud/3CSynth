// MIDIProcessor.swift
// Shared
//
// CoreMIDI receiver for the standalone iOS/macOS app.
// The AUv3 plug-in receives MIDI via AURenderEvent instead.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import CoreMIDI
import Foundation

// MARK: - MIDIProcessor

/// Connects to CoreMIDI and forwards messages to a ``SynthEngine``.
///
/// Instantiate once and retain for the application's lifetime.
/// The `SynthEngine` reference is held weakly to avoid retain cycles.
public final class MIDIProcessor {

    // MARK: Properties

    private weak var engine: SynthEngine?
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef    = 0

    // MARK: Init

    public init(engine: SynthEngine) {
        self.engine = engine
        setupMIDI()
    }

    deinit {
        if inputPort  != 0 { MIDIPortDispose(inputPort) }
        if midiClient != 0 { MIDIClientDispose(midiClient) }
    }

    // MARK: Setup

    private func setupMIDI() {
        let status = MIDIClientCreateWithBlock("3CSynth" as CFString, &midiClient) { [weak self] notification in
            self?.handleMIDINotification(notification.pointee)
        }

        guard status == noErr else {
            print("[3CSynth MIDI] Client creation failed: \(status)")
            return
        }

        let portStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            "3CSynth Input" as CFString,
            MIDIProtocolID._1_0,
            &inputPort
        ) { [weak self] eventList, srcConnRefCon in
            self?.handleEventList(eventList.pointee)
        }

        guard portStatus == noErr else {
            print("[3CSynth MIDI] Input port creation failed: \(portStatus)")
            return
        }

        // Connect to all existing sources.
        connectAllSources()
    }

    private func connectAllSources() {
        let count = MIDIGetNumberOfSources()
        for i in 0 ..< count {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)
        }
    }

    // MARK: Event Processing

    private func handleEventList(_ list: MIDIEventList) {
        var packet = list.packet
        for _ in 0 ..< list.numPackets {
            let words = packet.words()
            processUniversalMIDI1_0(words: words, count: Int(packet.wordCount))
            packet = MIDIEventPacketNext(&packet).pointee
        }
    }

    private func processUniversalMIDI1_0(words: [UInt32], count: Int) {
        for word in words.prefix(count) {
            let statusByte = UInt8((word >> 16) & 0xFF)
            let data1      = UInt8((word >>  8) & 0xFF)
            let data2      = UInt8((word >>  0) & 0xFF)
            let status     = statusByte & 0xF0

            switch status {
            case 0x90 where data2 > 0:
                engine?.noteOn(note: data1, velocity: data2)
            case 0x90, 0x80:
                engine?.noteOff(note: data1)
            case 0xB0:
                switch data1 {
                case  1: engine?.setModWheel(Float(data2) / 127.0)
                case 123: engine?.allNotesOff()
                default: break
                }
            case 0xE0:
                let raw14 = Int(data2) << 7 | Int(data1)
                let norm  = Float(raw14 - 8192) / 8192.0
                engine?.setPitchBend(norm)
            default:
                break
            }
        }
    }

    // MARK: Notification Handling

    private func handleMIDINotification(_ notification: MIDINotification) {
        if notification.messageID == .msgObjectAdded {
            connectAllSources()
        }
    }
}

// MARK: - MIDIEventPacket Word Accessor

private extension MIDIEventPacket {
    func words() -> [UInt32] {
        withUnsafeBytes(of: self.words) { raw in
            let ptr = raw.bindMemory(to: UInt32.self)
            return Array(ptr.prefix(Int(wordCount)))
        }
    }
}
