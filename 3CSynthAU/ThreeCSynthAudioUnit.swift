// ThreeCSynthAudioUnit.swift
// 3CSynthAU
//
// AUv3 Audio Unit extension entry-point.
// Bridges the `SynthEngine` DSP layer to the Audio Unit v3 API so that
// Logic Pro (and GarageBand, AUM, etc.) can host 3CSynth as an instrument plug-in.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AudioToolbox
import AVFoundation
import CoreAudioKit

// MARK: - ThreeCSynthAudioUnit

/// The `AUAudioUnit` subclass registered with the system as the 3CSynth instrument.
///
/// Logic Pro loads this class when the user inserts 3CSynth onto a Software
/// Instrument track. The render block runs on a real-time audio thread managed
/// by the host; all paths inside it must be allocation-free and lock-free.
///
/// **Component Description**
/// ```
/// type:         kAudioUnitType_MusicDevice  (0x61756d75)
/// subtype:      'Prsm'                      (0x5072736d)
/// manufacturer: 'Prma'                      (your registered code)
/// ```
public final class ThreeCSynthAudioUnit: AUAudioUnit {

    // MARK: Properties

    private let engine = SynthEngine()

    /// Shared parameter model; also owned by the view controller for UI binding.
    public var synthParameters: SynthParameters { engine.parameters }
    private var _parameterTree: AUParameterTree!
    private var _outputBus: AUAudioUnitBus!
    private var _outputBusArray: AUAudioUnitBusArray!

    // MARK: Init

    public override init(componentDescription: AudioComponentDescription,
                         options: AudioComponentInstantiationOptions = []) throws {
        try super.init(componentDescription: componentDescription, options: options)

        // Build the parameter tree first; the tree retains weak refs to `synthParameters`.
        _parameterTree = synthParameters.buildParameterTree()

        // Set up a stereo output bus with 32-bit float PCM.
        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        _outputBus = try AUAudioUnitBus(format: stereoFormat)
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

    /// 3CSynth is a Music Device (instrument), not an effect – no input buses.
    public override var inputBusses: AUAudioUnitBusArray {
        AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
    }

    public override var manufacturerName: String { "3CSynth Audio" }
    public override var audioUnitName: String? { "3CSynth" }
    // audioUnitVersion is not overridable; version is declared in Info.plist.

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        let sr = outputBusses[0].format.sampleRate
        engine.configure(sampleRate: sr)
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
    }

    // MARK: Real-Time Render Block

    /// Returns a closure that is safe to call on a real-time audio thread.
    ///
    /// The block captures value-type DSP state only; it holds no strong
    /// references to Objective-C objects that might call into the Swift runtime.
    public override var internalRenderBlock: AUInternalRenderBlock {

        // Capture by value / unowned to stay allocation-free at render time.
        let engineRef = engine
        let paramsRef = synthParameters

        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber,
                              outputData, realtimeEventListHead, pullInputBlock in

            // Process MIDI events queued by the host.
            self?.processMIDIEvents(realtimeEventListHead, frameCount: frameCount)

            // Render audio.
            engineRef.render(outputBufferList: outputData, frameCount: frameCount)

            return noErr
        }
    }

    // MARK: MIDI / AURenderEvent Processing

    private func processMIDIEvents(
        _ eventListHead: UnsafePointer<AURenderEvent>?,
        frameCount: AUAudioFrameCount
    ) {
        var event = eventListHead
        while let ev = event {
            switch ev.pointee.head.eventType {
            case .MIDI:
                handleMIDI(ev.pointee.MIDI)
            case .midiSysEx:
                break   // Not implemented.
            case .parameter, .parameterRamp:
                break   // Handled by the parameter tree.
            default:
                break
            }
            event = UnsafePointer(ev.pointee.head.next)
        }
    }

    private func handleMIDI(_ event: AUMIDIEvent) {
        let status  = event.data.0 & 0xF0
        let note    = event.data.1
        let value   = event.data.2

        switch status {
        case 0x90 where value > 0:   // Note On
            engine.noteOn(note: note, velocity: value)

        case 0x90, 0x80:             // Note Off (or Note On with vel 0)
            engine.noteOff(note: note)

        case 0xB0:                   // Control Change
            switch note {
            case  1: engine.setModWheel(Float(value) / 127.0)
            case 123: engine.allNotesOff()
            default: break
            }

        case 0xE0:                   // Pitch Bend (14-bit, centre = 8192)
            let raw = Int(value) << 7 | Int(note)
            let normalised = Float(raw - 8192) / 8192.0
            engine.setPitchBend(normalised)

        default:
            break
        }
    }

    // MARK: Preset State

    public override var fullState: [String: Any]? {
        get {
            guard let data = try? JSONEncoder().encode(
                synthParameters.makePreset(name: "State")
            ) else { return nil }
            return ["prismPreset": data]
        }
        set {
            guard let dict = newValue,
                  let data = dict["prismPreset"] as? Data,
                  let preset = try? JSONDecoder().decode(Preset.self, from: data) else { return }
            synthParameters.apply(preset)
        }
    }

    // MARK: Factory Presets

    public override var factoryPresets: [AUAudioUnitPreset]? {
        PresetManager().factoryPresets.enumerated().map { idx, preset in
            let p = AUAudioUnitPreset()
            p.number = idx
            p.name = preset.name
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
