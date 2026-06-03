// Preset.swift
// 3CSynth
//
// Codable preset data model and a curated factory preset library.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Foundation

// MARK: - Preset

/// A named snapshot of all ``SynthParameters`` values.
///
/// Presets are `Codable` and stored as JSON, making them trivial to
/// serialize into Audio Unit state (`auPreset` bundles) or share as files.
public struct Preset: Identifiable, Codable, Hashable, Sendable {

    public let id: UUID
    public var name: String
    public var category: PresetCategory
    public var author: String

    // Master
    public var masterVolume: Float
    public var stereoWidth: Float

    // Oscillator 1
    public var osc1Waveform: Int
    public var osc1Detune: Float
    public var osc1Octave: Int
    public var osc1Level: Float
    public var osc1WavetableIndex: Int

    // Oscillator 2
    public var osc2Waveform: Int
    public var osc2Detune: Float
    public var osc2Octave: Int
    public var osc2Level: Float
    public var osc2WavetableIndex: Int

    // Filter
    public var filterCutoff: Float
    public var filterResonance: Float
    public var filterMode: Int

    // Filter Envelope
    public var filterEnvAttack: Float
    public var filterEnvDecay: Float
    public var filterEnvSustain: Float
    public var filterEnvRelease: Float
    public var filterEnvAmount: Float

    // Amp Envelope
    public var ampAttack: Float
    public var ampDecay: Float
    public var ampSustain: Float
    public var ampRelease: Float

    // LFO 1
    public var lfo1Waveform: Int
    public var lfo1Rate: Float
    public var lfo1Depth: Float

    // Effects
    public var reverbMix: Float
    public var delayTime: Float
    public var delayFeedback: Float
    public var delayMix: Float

    public init(id: UUID = UUID(),
                name: String,
                category: PresetCategory = .other,
                author: String = "3CSynth") {
        self.id = id
        self.name = name
        self.category = category
        self.author = author

        // Defaults mirror `SynthParameters` init.
        masterVolume = 0.8; stereoWidth = 0.5
        osc1Waveform = OscillatorWaveform.sawtooth.rawValue
        osc1Detune = 0; osc1Octave = 0; osc1Level = 0.8; osc1WavetableIndex = 0
        osc2Waveform = OscillatorWaveform.sawtooth.rawValue
        osc2Detune = -7; osc2Octave = 0; osc2Level = 0.5; osc2WavetableIndex = 0
        filterCutoff = 3_000; filterResonance = 0.5; filterMode = FilterMode.lowPass.rawValue
        filterEnvAttack = 0.01; filterEnvDecay = 0.4; filterEnvSustain = 0.3
        filterEnvRelease = 0.5; filterEnvAmount = 2_000
        ampAttack = 0.005; ampDecay = 0.2; ampSustain = 0.7; ampRelease = 0.4
        lfo1Waveform = LFOWaveform.sine.rawValue; lfo1Rate = 1.0; lfo1Depth = 0
        reverbMix = 0.1; delayTime = 0.25; delayFeedback = 0.3; delayMix = 0
    }
}

// MARK: - PresetCategory

public enum PresetCategory: String, CaseIterable, Codable, Sendable {
    case bass       = "Bass"
    case lead       = "Lead"
    case pad        = "Pad"
    case keys       = "Keys"
    case pluck      = "Pluck"
    case sequence   = "Sequence"
    case other      = "Other"
}

// MARK: - SynthParameters ↔ Preset Bridge

public extension SynthParameters {

    /// Applies all values from `preset` to this parameter store.
    func apply(_ preset: Preset) {
        masterVolume        = preset.masterVolume
        stereoWidth         = preset.stereoWidth
        osc1Waveform        = OscillatorWaveform(rawValue: preset.osc1Waveform) ?? .sawtooth
        osc1Detune          = preset.osc1Detune
        osc1Octave          = preset.osc1Octave
        osc1Level           = preset.osc1Level
        osc1WavetableIndex  = preset.osc1WavetableIndex
        osc2Waveform        = OscillatorWaveform(rawValue: preset.osc2Waveform) ?? .sawtooth
        osc2Detune          = preset.osc2Detune
        osc2Octave          = preset.osc2Octave
        osc2Level           = preset.osc2Level
        osc2WavetableIndex  = preset.osc2WavetableIndex
        filterCutoff        = preset.filterCutoff
        filterResonance     = preset.filterResonance
        filterMode          = FilterMode(rawValue: preset.filterMode) ?? .lowPass
        filterEnvAttack     = preset.filterEnvAttack
        filterEnvDecay      = preset.filterEnvDecay
        filterEnvSustain    = preset.filterEnvSustain
        filterEnvRelease    = preset.filterEnvRelease
        filterEnvAmount     = preset.filterEnvAmount
        ampAttack           = preset.ampAttack
        ampDecay            = preset.ampDecay
        ampSustain          = preset.ampSustain
        ampRelease          = preset.ampRelease
        lfo1Waveform        = LFOWaveform(rawValue: preset.lfo1Waveform) ?? .sine
        lfo1Rate            = preset.lfo1Rate
        lfo1Depth           = preset.lfo1Depth
        reverbMix           = preset.reverbMix
        delayTime           = preset.delayTime
        delayFeedback       = preset.delayFeedback
        delayMix            = preset.delayMix
    }

    /// Creates a `Preset` snapshot from the current parameter values.
    func makePreset(name: String, category: PresetCategory = .other) -> Preset {
        var p = Preset(name: name, category: category)
        p.masterVolume        = masterVolume
        p.stereoWidth         = stereoWidth
        p.osc1Waveform        = osc1Waveform.rawValue
        p.osc1Detune          = osc1Detune
        p.osc1Octave          = osc1Octave
        p.osc1Level           = osc1Level
        p.osc1WavetableIndex  = osc1WavetableIndex
        p.osc2Waveform        = osc2Waveform.rawValue
        p.osc2Detune          = osc2Detune
        p.osc2Octave          = osc2Octave
        p.osc2Level           = osc2Level
        p.osc2WavetableIndex  = osc2WavetableIndex
        p.filterCutoff        = filterCutoff
        p.filterResonance     = filterResonance
        p.filterMode          = filterMode.rawValue
        p.filterEnvAttack     = filterEnvAttack
        p.filterEnvDecay      = filterEnvDecay
        p.filterEnvSustain    = filterEnvSustain
        p.filterEnvRelease    = filterEnvRelease
        p.filterEnvAmount     = filterEnvAmount
        p.ampAttack           = ampAttack
        p.ampDecay            = ampDecay
        p.ampSustain          = ampSustain
        p.ampRelease          = ampRelease
        p.lfo1Waveform        = lfo1Waveform.rawValue
        p.lfo1Rate            = lfo1Rate
        p.lfo1Depth           = lfo1Depth
        p.reverbMix           = reverbMix
        p.delayTime           = delayTime
        p.delayFeedback       = delayFeedback
        p.delayMix            = delayMix
        return p
    }
}
