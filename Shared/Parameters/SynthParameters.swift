// SynthParameters.swift
// 3CSynth
//
// Central parameter store shared between the AUv3 parameter tree and the UI.
// Conforms to `Observable` so SwiftUI views update automatically.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AudioToolbox
import Foundation
import Observation

// MARK: - SynthParameters

/// The complete parameter state of the 3CSynth.
///
/// `SynthParameters` is the single source of truth for both the DSP engine
/// and the SwiftUI interface. The ``ThreeCSynthAudioUnit`` keeps an instance and
/// bridges each property to an ``AUParameter`` so that Logic Pro can automate
/// and save/recall all values in a session.
///
/// Parameters are grouped by synthesis section to mirror the visual layout
/// of the instrument UI.
@Observable
public final class SynthParameters {

    // MARK: Master

    /// Output volume, 0 … 1.
    public var masterVolume: Float = 0.8

    /// Global transpose in semitones, –24 … +24.
    public var transpose: Float = 0

    /// Stereo width applied by the voice panning model, 0 … 1.
    public var stereoWidth: Float = 0.5

    // MARK: Oscillator 1

    public var osc1Waveform: OscillatorWaveform = .sawtooth
    /// Detune in cents, –100 … +100.
    public var osc1Detune: Float = 0
    /// Octave offset, –2 … +2.
    public var osc1Octave: Int = 0
    /// Output level, 0 … 1.
    public var osc1Level: Float = 0.8
    /// Wavetable selection index (used when `osc1Waveform == .wavetable`).
    public var osc1WavetableIndex: Int = 0

    // MARK: Oscillator 2

    public var osc2Waveform: OscillatorWaveform = .sawtooth
    /// Detune in cents, –100 … +100.
    public var osc2Detune: Float = -7      // slight detune for thickness
    public var osc2Octave: Int = 0
    public var osc2Level: Float = 0.5
    public var osc2WavetableIndex: Int = 0

    // MARK: Filter

    /// Filter cutoff frequency in Hz, 20 … 20 000.
    public var filterCutoff: Float = 3_000
    /// Filter resonance, 0.1 … 20.
    public var filterResonance: Float = 0.5
    public var filterMode: FilterMode = .lowPass

    // MARK: Filter Envelope

    public var filterEnvAttack: Float  = 0.01
    public var filterEnvDecay: Float   = 0.4
    public var filterEnvSustain: Float = 0.3
    public var filterEnvRelease: Float = 0.5
    /// How much the filter envelope modulates the cutoff (±10 000 Hz).
    public var filterEnvAmount: Float  = 2_000

    // MARK: Amp Envelope

    public var ampAttack: Float  = 0.005
    public var ampDecay: Float   = 0.2
    public var ampSustain: Float = 0.7
    public var ampRelease: Float = 0.4

    // MARK: LFO 1

    public var lfo1Waveform: LFOWaveform = .sine
    /// Rate in Hz, 0.1 … 20.
    public var lfo1Rate: Float = 1.0
    /// Modulation depth, 0 … 1.
    public var lfo1Depth: Float = 0

    // MARK: Effects (placeholder for future reverb/delay expansion)

    public var reverbMix: Float = 0.1
    public var delayTime: Float = 0.25
    public var delayFeedback: Float = 0.3
    public var delayMix: Float = 0.0

    public init() {}
}

// MARK: - AUParameterTree Builder

public extension SynthParameters {

    /// Constructs an `AUParameterTree` whose leaves are kept in sync with
    /// this `SynthParameters` instance.
    ///
    /// - Parameter audioUnit: The owning `AUAudioUnit`; retained weakly so
    ///   the parameter observer can forward changes.
    func buildParameterTree() -> AUParameterTree {

        var params: [AUParameter] = []

        // --- Master ---
        params.append(makeParam(.masterVolume,      address: 0,  min: 0,      max: 1,       unit: .linearGain,      name: "Volume"))
        params.append(makeParam(.transpose,         address: 1,  min: -24,    max: 24,      unit: .midiNoteNumber,  name: "Transpose"))
        params.append(makeParam(.stereoWidth,       address: 2,  min: 0,      max: 1,       unit: .generic,         name: "Stereo Width"))

        // --- Oscillator 1 ---
        params.append(makeParam(.osc1Waveform,      address: 10, min: 0,      max: 4,       unit: .indexed,         name: "Osc 1 Waveform"))
        params.append(makeParam(.osc1Detune,        address: 11, min: -100,   max: 100,     unit: .cents,           name: "Osc 1 Detune"))
        params.append(makeParam(.osc1Octave,        address: 12, min: -2,     max: 2,       unit: .octaves,         name: "Osc 1 Octave"))
        params.append(makeParam(.osc1Level,         address: 13, min: 0,      max: 1,       unit: .linearGain,      name: "Osc 1 Level"))
        params.append(makeParam(.osc1WavetableIdx,  address: 14, min: 0,      max: 15,      unit: .indexed,         name: "Osc 1 Table"))

        // --- Oscillator 2 ---
        params.append(makeParam(.osc2Waveform,      address: 20, min: 0,      max: 4,       unit: .indexed,         name: "Osc 2 Waveform"))
        params.append(makeParam(.osc2Detune,        address: 21, min: -100,   max: 100,     unit: .cents,           name: "Osc 2 Detune"))
        params.append(makeParam(.osc2Octave,        address: 22, min: -2,     max: 2,       unit: .octaves,         name: "Osc 2 Octave"))
        params.append(makeParam(.osc2Level,         address: 23, min: 0,      max: 1,       unit: .linearGain,      name: "Osc 2 Level"))
        params.append(makeParam(.osc2WavetableIdx,  address: 24, min: 0,      max: 15,      unit: .indexed,         name: "Osc 2 Table"))

        // --- Filter ---
        params.append(makeParam(.filterCutoff,      address: 30, min: 20,     max: 20_000,  unit: .hertz,           name: "Filter Cutoff"))
        params.append(makeParam(.filterResonance,   address: 31, min: 0.1,    max: 20,      unit: .generic,         name: "Filter Resonance"))
        params.append(makeParam(.filterMode,        address: 32, min: 0,      max: 3,       unit: .indexed,         name: "Filter Mode"))

        // --- Filter Envelope ---
        params.append(makeParam(.filterEnvAttack,   address: 40, min: 0.001,  max: 10,      unit: .seconds,         name: "Flt Env Attack"))
        params.append(makeParam(.filterEnvDecay,    address: 41, min: 0.001,  max: 10,      unit: .seconds,         name: "Flt Env Decay"))
        params.append(makeParam(.filterEnvSustain,  address: 42, min: 0,      max: 1,       unit: .linearGain,      name: "Flt Env Sustain"))
        params.append(makeParam(.filterEnvRelease,  address: 43, min: 0.001,  max: 15,      unit: .seconds,         name: "Flt Env Release"))
        params.append(makeParam(.filterEnvAmount,   address: 44, min: -10_000, max: 10_000, unit: .hertz,           name: "Flt Env Amount"))

        // --- Amp Envelope ---
        params.append(makeParam(.ampAttack,         address: 50, min: 0.001,  max: 10,      unit: .seconds,         name: "Amp Attack"))
        params.append(makeParam(.ampDecay,          address: 51, min: 0.001,  max: 10,      unit: .seconds,         name: "Amp Decay"))
        params.append(makeParam(.ampSustain,        address: 52, min: 0,      max: 1,       unit: .linearGain,      name: "Amp Sustain"))
        params.append(makeParam(.ampRelease,        address: 53, min: 0.001,  max: 15,      unit: .seconds,         name: "Amp Release"))

        // --- LFO 1 ---
        params.append(makeParam(.lfo1Waveform,      address: 60, min: 0,      max: 4,       unit: .indexed,         name: "LFO 1 Wave"))
        params.append(makeParam(.lfo1Rate,          address: 61, min: 0.1,    max: 20,      unit: .hertz,           name: "LFO 1 Rate"))
        params.append(makeParam(.lfo1Depth,         address: 62, min: 0,      max: 1,       unit: .generic,         name: "LFO 1 Depth"))

        // --- Effects ---
        params.append(makeParam(.reverbMix,         address: 70, min: 0,      max: 1,       unit: .generic,         name: "Reverb Mix"))
        params.append(makeParam(.delayTime,         address: 71, min: 0.01,   max: 2,       unit: .seconds,         name: "Delay Time"))
        params.append(makeParam(.delayFeedback,     address: 72, min: 0,      max: 0.95,    unit: .generic,         name: "Delay Feedback"))
        params.append(makeParam(.delayMix,          address: 73, min: 0,      max: 1,       unit: .generic,         name: "Delay Mix"))

        let tree = AUParameterTree.createTree(withChildren: params)

        // Wire the parameter tree to self; changes from the host update our store.
        tree.implementorValueObserver = { [weak self] param, value in
            self?.apply(address: param.address, value: value)
        }

        tree.implementorValueProvider = { [weak self] param in
            self?.valueFor(address: param.address) ?? 0
        }

        return tree
    }

    // MARK: Private Factories

    private func makeParam(_ id: ParameterAddress,
                           address: AUParameterAddress,
                           min: AUValue,
                           max: AUValue,
                           unit: AudioUnitParameterUnit,
                           name: String) -> AUParameter {
        AUParameterTree.createParameter(
            withIdentifier: id.identifier,
            name: name,
            address: address,
            min: min,
            max: max,
            unit: unit,
            unitName: nil,
            flags: [.flag_IsReadable, .flag_IsWritable],
            valueStrings: nil,
            dependentParameters: nil
        )
    }

    // MARK: Bidirectional Sync

    /// Applies a host-driven parameter change to the corresponding property.
    func apply(address: AUParameterAddress, value: AUValue) {
        switch ParameterAddress(rawAddress: address) {
        case .masterVolume:     masterVolume    = value
        case .transpose:        transpose       = value
        case .stereoWidth:      stereoWidth     = value
        case .osc1Waveform:     osc1Waveform    = OscillatorWaveform(rawValue: Int(value)) ?? .sawtooth
        case .osc1Detune:       osc1Detune      = value
        case .osc1Octave:       osc1Octave      = Int(value)
        case .osc1Level:        osc1Level       = value
        case .osc1WavetableIdx: osc1WavetableIndex = Int(value)
        case .osc2Waveform:     osc2Waveform    = OscillatorWaveform(rawValue: Int(value)) ?? .sawtooth
        case .osc2Detune:       osc2Detune      = value
        case .osc2Octave:       osc2Octave      = Int(value)
        case .osc2Level:        osc2Level       = value
        case .osc2WavetableIdx: osc2WavetableIndex = Int(value)
        case .filterCutoff:     filterCutoff    = value
        case .filterResonance:  filterResonance = value
        case .filterMode:       filterMode      = FilterMode(rawValue: Int(value)) ?? .lowPass
        case .filterEnvAttack:  filterEnvAttack = value
        case .filterEnvDecay:   filterEnvDecay  = value
        case .filterEnvSustain: filterEnvSustain = value
        case .filterEnvRelease: filterEnvRelease = value
        case .filterEnvAmount:  filterEnvAmount = value
        case .ampAttack:        ampAttack       = value
        case .ampDecay:         ampDecay        = value
        case .ampSustain:       ampSustain      = value
        case .ampRelease:       ampRelease      = value
        case .lfo1Waveform:     lfo1Waveform    = LFOWaveform(rawValue: Int(value)) ?? .sine
        case .lfo1Rate:         lfo1Rate        = value
        case .lfo1Depth:        lfo1Depth       = value
        case .reverbMix:        reverbMix       = value
        case .delayTime:        delayTime       = value
        case .delayFeedback:    delayFeedback   = value
        case .delayMix:         delayMix        = value
        case .none:             break
        }
    }

    /// Returns the current value for a given parameter address.
    func valueFor(address: AUParameterAddress) -> AUValue {
        switch ParameterAddress(rawAddress: address) {
        case .masterVolume:     return masterVolume
        case .transpose:        return transpose
        case .stereoWidth:      return stereoWidth
        case .osc1Waveform:     return AUValue(osc1Waveform.rawValue)
        case .osc1Detune:       return osc1Detune
        case .osc1Octave:       return AUValue(osc1Octave)
        case .osc1Level:        return osc1Level
        case .osc1WavetableIdx: return AUValue(osc1WavetableIndex)
        case .osc2Waveform:     return AUValue(osc2Waveform.rawValue)
        case .osc2Detune:       return osc2Detune
        case .osc2Octave:       return AUValue(osc2Octave)
        case .osc2Level:        return osc2Level
        case .osc2WavetableIdx: return AUValue(osc2WavetableIndex)
        case .filterCutoff:     return filterCutoff
        case .filterResonance:  return filterResonance
        case .filterMode:       return AUValue(filterMode.rawValue)
        case .filterEnvAttack:  return filterEnvAttack
        case .filterEnvDecay:   return filterEnvDecay
        case .filterEnvSustain: return filterEnvSustain
        case .filterEnvRelease: return filterEnvRelease
        case .filterEnvAmount:  return filterEnvAmount
        case .ampAttack:        return ampAttack
        case .ampDecay:         return ampDecay
        case .ampSustain:       return ampSustain
        case .ampRelease:       return ampRelease
        case .lfo1Waveform:     return AUValue(lfo1Waveform.rawValue)
        case .lfo1Rate:         return lfo1Rate
        case .lfo1Depth:        return lfo1Depth
        case .reverbMix:        return reverbMix
        case .delayTime:        return delayTime
        case .delayFeedback:    return delayFeedback
        case .delayMix:         return delayMix
        case .none:             return 0
        }
    }
}

// MARK: - ParameterAddress

/// Type-safe enumeration of AU parameter addresses.
private enum ParameterAddress {
    case masterVolume, transpose, stereoWidth
    case osc1Waveform, osc1Detune, osc1Octave, osc1Level, osc1WavetableIdx
    case osc2Waveform, osc2Detune, osc2Octave, osc2Level, osc2WavetableIdx
    case filterCutoff, filterResonance, filterMode
    case filterEnvAttack, filterEnvDecay, filterEnvSustain, filterEnvRelease, filterEnvAmount
    case ampAttack, ampDecay, ampSustain, ampRelease
    case lfo1Waveform, lfo1Rate, lfo1Depth
    case reverbMix, delayTime, delayFeedback, delayMix
    case none

    var identifier: String { "\(self)" }

    init(rawAddress: AUParameterAddress) {
        switch rawAddress {
        case  0: self = .masterVolume
        case  1: self = .transpose
        case  2: self = .stereoWidth
        case 10: self = .osc1Waveform
        case 11: self = .osc1Detune
        case 12: self = .osc1Octave
        case 13: self = .osc1Level
        case 14: self = .osc1WavetableIdx
        case 20: self = .osc2Waveform
        case 21: self = .osc2Detune
        case 22: self = .osc2Octave
        case 23: self = .osc2Level
        case 24: self = .osc2WavetableIdx
        case 30: self = .filterCutoff
        case 31: self = .filterResonance
        case 32: self = .filterMode
        case 40: self = .filterEnvAttack
        case 41: self = .filterEnvDecay
        case 42: self = .filterEnvSustain
        case 43: self = .filterEnvRelease
        case 44: self = .filterEnvAmount
        case 50: self = .ampAttack
        case 51: self = .ampDecay
        case 52: self = .ampSustain
        case 53: self = .ampRelease
        case 60: self = .lfo1Waveform
        case 61: self = .lfo1Rate
        case 62: self = .lfo1Depth
        case 70: self = .reverbMix
        case 71: self = .delayTime
        case 72: self = .delayFeedback
        case 73: self = .delayMix
        default: self = .none
        }
    }
}
