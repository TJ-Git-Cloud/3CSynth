// ThreeCSynthMacAudioUnit.swift
// 3CSynthAUMac
//
// AUv3 Audio Unit for the macOS Logic Pro plug-in.
// Identical logic to the iOS AU; separate class name avoids symbol collisions
// when both targets are linked into the same process during development.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AudioToolbox
import AVFoundation
import CoreAudioKit

// MARK: - ThreeCSynthMacAudioUnit

/// The `AUAudioUnit` subclass registered with macOS as the 3CSynth instrument.
///
/// Logic Pro on Mac loads this class when the user inserts 3CSynth onto a
/// Software Instrument track. The render block runs on a real-time audio
/// thread; all paths inside it must be allocation-free and lock-free.
public final class ThreeCSynthMacAudioUnit: AUAudioUnit {

    // MARK: Properties

    public let synthParameters = SynthParameters()

    private let engine = SynthEngine()
    private var _parameterTree: AUParameterTree!
    private var _outputBus: AUAudioUnitBus!
    private var _outputBusArray: AUAudioUnitBusArray!

    // MARK: Init

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        _parameterTree = synthParameters.buildParameterTree()

        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        _outputBus      = try AUAudioUnitBus(format: stereoFormat)
        _outputBusArray = AUAudioUnitBusArray(audioUnit: self,
                                              busType: .output,
                                              busses: [_outputBus])
        maximumFramesToRender = 4096
    }

    // MARK: AUAudioUnit Overrides

    public override var parameterTree: AUParameterTree? {
        get { _parameterTree }
        set { _parameterTree = newValue }
    }

    public override var outputBusses: AUAudioUnitBusArray { _outputBusArray }

    public override var inputBusses: AUAudioUnitBusArray {
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }

    public override var manufacturerName: String  { "3CSynth Audio" }
    public override var audioUnitName:    String? { "3CSynth" }
    // audioUnitVersion is not overridable on macOS; version is declared in Info.plist.

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        engine.configure(sampleRate: outputBusses[0].format.sampleRate)
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
    }

    // MARK: Real-Time Render Block

    public override var internalRenderBlock: AUInternalRenderBlock {
        let engineRef = engine

        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber,
                              outputData, realtimeEventListHead, pullInputBlock in

            self?.processMIDIEvents(realtimeEventListHead, frameCount: frameCount)
            engineRef.render(outputBufferList: outputData, frameCount: frameCount)
            return noErr
        }
    }

    // MARK: MIDI Processing

    private func processMIDIEvents(
        _ eventListHead: UnsafePointer<AURenderEvent>?,
        frameCount: AUAudioFrameCount
    ) {
        var event = eventListHead
        while let ev = event {
            switch ev.pointee.head.eventType {
            case .MIDI: handleMIDI(ev.pointee.MIDI)
            default:    break
            }
            event = UnsafePointer(ev.pointee.head.next)
        }
    }

    private func handleMIDI(_ event: AUMIDIEvent) {
        let status = event.data.0 & 0xF0
        let note   = event.data.1
        let value  = event.data.2

        switch status {
        case 0x90 where value > 0:
            engine.noteOn(note: note, velocity: value)
        case 0x90, 0x80:
            engine.noteOff(note: note)
        case 0xB0:
            switch note {
            case  1: engine.setModWheel(Float(value) / 127.0)
            case 123: engine.allNotesOff()
            default: break
            }
        case 0xE0:
            let raw = Int(value) << 7 | Int(note)
            engine.setPitchBend(Float(raw - 8192) / 8192.0)
        default:
            break
        }
    }

    // MARK: Preset State (Logic Pro patch save/load)

    public override var fullState: [String: Any]? {
        get {
            guard let data = try? JSONEncoder().encode(
                synthParameters.makePreset(name: "State")
            ) else { return nil }
            return ["threecSynthPreset": data]
        }
        set {
            guard let dict   = newValue,
                  let data   = dict["threecSynthPreset"] as? Data,
                  let preset = try? JSONDecoder().decode(Preset.self, from: data)
            else { return }
            synthParameters.apply(preset)
        }
    }

    // MARK: Factory Presets

    public override var factoryPresets: [AUAudioUnitPreset]? {
        PresetManager().factoryPresets.enumerated().map { idx, preset in
            let p = AUAudioUnitPreset()
            p.number = idx
            p.name   = preset.name
            return p
        }
    }

    public override var currentPreset: AUAudioUnitPreset? {
        get { super.currentPreset }
        set {
            super.currentPreset = newValue
            guard let number = newValue?.number, number >= 0 else { return }
            let manager = PresetManager()
            if manager.factoryPresets.indices.contains(number) {
                synthParameters.apply(manager.factoryPresets[number])
            }
        }
    }
}
