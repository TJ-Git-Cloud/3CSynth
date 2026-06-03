// PresetManager.swift
// 3CSynth
//
// Manages factory and user presets, with JSON persistence to the app's
// Application Support directory.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Foundation
import Observation

// MARK: - PresetManager

/// Loads, saves, and organises ``Preset`` instances.
///
/// Factory presets are compiled into the bundle and are read-only.
/// User presets are saved to `~/Library/Application Support/3CSynth/Presets/`.
@Observable
public final class PresetManager {

    // MARK: Published State

    public private(set) var factoryPresets: [Preset] = []
    public private(set) var userPresets: [Preset] = []

    /// Convenience: factory + user, grouped.
    public var allPresets: [Preset] { factoryPresets + userPresets }

    // Serialises concurrent save/delete calls so neither overwrites the other.
    private let persistQueue = DispatchQueue(label: "com.3csynth.presets")

    // MARK: Init

    public init() {
        factoryPresets = Self.buildFactoryPresets()
        loadUserPresets()
    }

    // MARK: Persistence

    public func save(preset: Preset) throws {
        try persistQueue.sync {
            var presets = userPresets
            if let existing = presets.firstIndex(where: { $0.id == preset.id }) {
                presets[existing] = preset
            } else {
                presets.append(preset)
            }
            try persist(presets)
            userPresets = presets
        }
    }

    public func delete(preset: Preset) throws {
        try persistQueue.sync {
            let updated = userPresets.filter { $0.id != preset.id }
            try persist(updated)
            userPresets = updated
        }
    }

    // MARK: Private Persistence

    private func loadUserPresets() {
        let url = presetsDirectoryURL.appendingPathComponent("user.json")
        guard let data = try? Data(contentsOf: url) else { return }
        userPresets = (try? JSONDecoder().decode([Preset].self, from: data)) ?? []
    }

    private func persist(_ presets: [Preset]) throws {
        try FileManager.default.createDirectory(at: presetsDirectoryURL,
                                                withIntermediateDirectories: true)
        let url  = presetsDirectoryURL.appendingPathComponent("user.json")
        let data = try JSONEncoder().encode(presets)
        try data.write(to: url, options: .atomicWrite)
    }

    private var presetsDirectoryURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first!
        return appSupport.appendingPathComponent("3CSynth/Presets", isDirectory: true)
    }

    // MARK: Factory Presets

    private static func buildFactoryPresets() -> [Preset] {
        [
            // --- Basses ---
            makeBass_SubDrop(),
            makeBass_Acid(),

            // --- Leads ---
            makeLead_ClassicSaw(),
            makeLead_Pulse(),
            makeLead_Screamer(),

            // --- Pads ---
            makePad_Strings(),
            makePad_Atmosphere(),
            makePad_Warmth(),

            // --- Keys ---
            makeKeys_ElectricPiano(),
            makeKeys_Organ(),

            // --- Pluck ---
            makePluck_Crystal(),
            makePluck_Harp(),
        ]
    }

    // MARK: Individual Factory Presets

    private static func makeBass_SubDrop() -> Preset {
        var p = Preset(name: "Sub Drop", category: .bass)
        p.osc1Waveform = OscillatorWaveform.sine.rawValue
        p.osc1Level = 0.9; p.osc1Octave = -1
        p.osc2Waveform = OscillatorWaveform.sawtooth.rawValue
        p.osc2Level = 0.3; p.osc2Detune = 5
        p.filterCutoff = 200; p.filterResonance = 0.3
        p.filterEnvAmount = 800; p.filterEnvAttack = 0; p.filterEnvDecay = 0.3
        p.ampAttack = 0.005; p.ampDecay = 0.3; p.ampSustain = 0.6; p.ampRelease = 0.5
        p.reverbMix = 0.05
        return p
    }

    private static func makeBass_Acid() -> Preset {
        var p = Preset(name: "Acid Bass", category: .bass)
        p.osc1Waveform = OscillatorWaveform.sawtooth.rawValue
        p.osc1Level = 0.9; p.osc1Octave = -1
        p.filterCutoff = 600; p.filterResonance = 8
        p.filterEnvAmount = 4_000; p.filterEnvAttack = 0.001; p.filterEnvDecay = 0.1
        p.ampAttack = 0.001; p.ampDecay = 0.1; p.ampSustain = 0.5; p.ampRelease = 0.15
        return p
    }

    private static func makeLead_ClassicSaw() -> Preset {
        var p = Preset(name: "Classic Saw Lead", category: .lead)
        p.osc1Waveform = OscillatorWaveform.sawtooth.rawValue; p.osc1Level = 0.8
        p.osc2Waveform = OscillatorWaveform.sawtooth.rawValue; p.osc2Level = 0.6; p.osc2Detune = 8
        p.filterCutoff = 4_000; p.filterResonance = 1.2
        p.ampAttack = 0.005; p.ampDecay = 0.3; p.ampSustain = 0.8; p.ampRelease = 0.2
        p.lfo1Depth = 0.15; p.lfo1Rate = 5.5
        p.reverbMix = 0.15
        return p
    }

    private static func makeLead_Pulse() -> Preset {
        var p = Preset(name: "Pulse Lead", category: .lead)
        p.osc1Waveform = OscillatorWaveform.square.rawValue; p.osc1Level = 0.75
        p.filterCutoff = 3_000; p.filterResonance = 0.8
        p.filterEnvAmount = 1_500; p.filterEnvDecay = 0.25
        p.ampAttack = 0.01; p.ampSustain = 0.7; p.ampRelease = 0.3
        p.lfo1Depth = 0.2; p.lfo1Rate = 6
        return p
    }

    private static func makeLead_Screamer() -> Preset {
        var p = Preset(name: "Screamer", category: .lead)
        p.osc1Waveform = OscillatorWaveform.sawtooth.rawValue
        p.osc2Waveform = OscillatorWaveform.square.rawValue
        p.osc1Level = 0.8; p.osc2Level = 0.7; p.osc2Detune = -12
        p.filterCutoff = 6_000; p.filterResonance = 2.5
        p.filterEnvAmount = 3_000; p.filterEnvAttack = 0.05
        p.ampAttack = 0.02; p.ampSustain = 0.85; p.ampRelease = 0.15
        p.reverbMix = 0.1
        return p
    }

    private static func makePad_Strings() -> Preset {
        var p = Preset(name: "Strings Pad", category: .pad)
        p.osc1Waveform = OscillatorWaveform.sawtooth.rawValue
        p.osc2Waveform = OscillatorWaveform.sawtooth.rawValue
        p.osc2Detune = 12; p.stereoWidth = 0.8
        p.filterCutoff = 2_000; p.filterResonance = 0.3
        p.ampAttack = 0.8; p.ampDecay = 0.4; p.ampSustain = 0.9; p.ampRelease = 1.5
        p.lfo1Depth = 0.05; p.lfo1Rate = 3
        p.reverbMix = 0.35
        return p
    }

    private static func makePad_Atmosphere() -> Preset {
        var p = Preset(name: "Atmosphere", category: .pad)
        p.osc1Waveform = OscillatorWaveform.wavetable.rawValue; p.osc1WavetableIndex = 3
        p.osc2Waveform = OscillatorWaveform.wavetable.rawValue; p.osc2WavetableIndex = 4
        p.osc2Detune = 7; p.stereoWidth = 1.0
        p.filterCutoff = 1_500; p.filterResonance = 0.2
        p.ampAttack = 1.5; p.ampDecay = 0.5; p.ampSustain = 0.85; p.ampRelease = 3.0
        p.reverbMix = 0.5; p.delayMix = 0.2; p.delayTime = 0.375
        return p
    }

    private static func makePad_Warmth() -> Preset {
        var p = Preset(name: "Warm Blanket", category: .pad)
        p.osc1Waveform = OscillatorWaveform.triangle.rawValue
        p.osc2Waveform = OscillatorWaveform.sine.rawValue; p.osc2Octave = 1
        p.osc2Level = 0.4; p.stereoWidth = 0.6
        p.filterCutoff = 1_200; p.filterResonance = 0.3
        p.ampAttack = 0.6; p.ampSustain = 0.95; p.ampRelease = 2.0
        p.reverbMix = 0.3
        return p
    }

    private static func makeKeys_ElectricPiano() -> Preset {
        var p = Preset(name: "Electric Piano", category: .keys)
        p.osc1Waveform = OscillatorWaveform.wavetable.rawValue; p.osc1WavetableIndex = 0
        p.osc2Waveform = OscillatorWaveform.sine.rawValue; p.osc2Level = 0.3
        p.filterCutoff = 5_000; p.filterResonance = 0.4
        p.filterEnvAmount = 2_000; p.filterEnvDecay = 0.3
        p.ampAttack = 0.002; p.ampDecay = 0.5; p.ampSustain = 0.4; p.ampRelease = 0.8
        p.reverbMix = 0.2
        return p
    }

    private static func makeKeys_Organ() -> Preset {
        var p = Preset(name: "Drawbar Organ", category: .keys)
        p.osc1Waveform = OscillatorWaveform.sine.rawValue; p.osc1Level = 0.9
        p.osc2Waveform = OscillatorWaveform.sine.rawValue; p.osc2Octave = 1; p.osc2Level = 0.6
        p.filterCutoff = 8_000; p.filterResonance = 0.2
        p.ampAttack = 0.001; p.ampDecay = 0.01; p.ampSustain = 1.0; p.ampRelease = 0.05
        p.reverbMix = 0.1
        return p
    }

    private static func makePluck_Crystal() -> Preset {
        var p = Preset(name: "Crystal Pluck", category: .pluck)
        p.osc1Waveform = OscillatorWaveform.wavetable.rawValue; p.osc1WavetableIndex = 5
        p.filterCutoff = 8_000; p.filterResonance = 3.0
        p.filterEnvAmount = 5_000; p.filterEnvDecay = 0.15
        p.ampAttack = 0.001; p.ampDecay = 0.6; p.ampSustain = 0.0; p.ampRelease = 0.5
        p.reverbMix = 0.25
        return p
    }

    private static func makePluck_Harp() -> Preset {
        var p = Preset(name: "Harp", category: .pluck)
        p.osc1Waveform = OscillatorWaveform.triangle.rawValue
        p.osc2Waveform = OscillatorWaveform.sine.rawValue; p.osc2Octave = 1; p.osc2Level = 0.4
        p.filterCutoff = 6_000; p.filterResonance = 0.5
        p.filterEnvAmount = 3_000; p.filterEnvDecay = 0.2
        p.ampAttack = 0.002; p.ampDecay = 0.8; p.ampSustain = 0.0; p.ampRelease = 0.7
        p.reverbMix = 0.3
        return p
    }
}
