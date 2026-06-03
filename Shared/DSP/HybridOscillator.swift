// HybridOscillator.swift
// 3CSynth
//
// A hybrid oscillator combining classic subtractive waveforms (with PolyBLEP
// anti-aliasing) and wavetable playback. Morphing between the two modes is
// controlled by `waveform`.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Foundation

// MARK: - Waveform

/// The set of waveforms available to each oscillator.
public enum OscillatorWaveform: Int, CaseIterable, Identifiable, Sendable {
    case sine       = 0
    case triangle   = 1
    case sawtooth   = 2
    case square     = 3
    case wavetable  = 4     // Reads from `WavetableBank`

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .sine:      return "Sine"
        case .triangle:  return "Triangle"
        case .sawtooth:  return "Sawtooth"
        case .square:    return "Square"
        case .wavetable: return "Wavetable"
        }
    }
}

// MARK: - HybridOscillator

/// Band-limited hybrid oscillator with PolyBLEP discontinuity correction.
///
/// In `.wavetable` mode the oscillator reads from ``WavetableBank/shared``
/// using linear interpolation and anti-aliasing via mip-map level selection.
///
/// All state mutations must happen *before* `render(into:frameCount:)` is
/// called, as rendering is not thread-safe.
struct HybridOscillator {

    // MARK: Parameters

    var frequency: Float    = 440.0
    var detune: Float       = 0.0          // ±100 cents
    var octave: Int         = 0            // –2…+2
    var level: Float        = 1.0          // 0…1
    var waveform: OscillatorWaveform = .sawtooth
    var pulseWidth: Float   = 0.5          // 0.1…0.9 (square only)
    var wavetableIndex: Int = 0            // index into WavetableBank

    var sampleRate: Double  = k3CSynthDefaultSampleRate

    // MARK: Private Phase State

    private var phase: Float = 0.0         // 0.0…1.0

    // MARK: Frequency Helpers

    /// Returns the effective frequency after applying octave and detune.
    var effectiveFrequency: Float {
        let octaveFactor = Float(pow(2.0, Double(octave)))
        let detuneFactor = Float(pow(2.0, Double(detune) / 1200.0))
        return frequency * octaveFactor * detuneFactor
    }

    /// Returns a detuned frequency relative to a base frequency (for osc2 spread).
    func detuneFrequency(base: Float) -> Float {
        let octaveFactor = Float(pow(2.0, Double(octave)))
        let detuneFactor = Float(pow(2.0, Double(detune) / 1200.0))
        return base * octaveFactor * detuneFactor
    }

    // MARK: Rendering

    /// Accumulates rendered samples into `buffer` (does not zero first).
    mutating func render(into buffer: inout [Float], frameCount: Int) {
        let freq = effectiveFrequency
        let sr   = Float(sampleRate)
        let phaseIncrement = freq / sr

        for i in 0 ..< frameCount {
            let sample: Float

            switch waveform {
            case .sine:
                sample = sin(phase * 2.0 * .pi)

            case .triangle:
                sample = triangleSample(phase: phase)

            case .sawtooth:
                sample = sawSample(phase: phase, phaseIncrement: phaseIncrement)

            case .square:
                sample = squareSample(phase: phase,
                                      phaseIncrement: phaseIncrement,
                                      pulseWidth: pulseWidth)

            case .wavetable:
                sample = WavetableBank.shared.sample(
                    tableIndex: wavetableIndex,
                    phase: phase,
                    frequency: freq,
                    sampleRate: sr
                )
            }

            buffer[i] += sample * level

            // Advance and wrap phase.
            phase += phaseIncrement
            if phase >= 1.0 { phase -= 1.0 }
        }
    }

    // MARK: Waveform Generators

    private func triangleSample(phase: Float) -> Float {
        let t = phase < 0.5 ? phase : 1.0 - phase
        return 4.0 * t - 1.0
    }

    /// Sawtooth with PolyBLEP anti-aliasing.
    private func sawSample(phase: Float, phaseIncrement: Float) -> Float {
        var raw = 2.0 * phase - 1.0
        raw -= polyBLEP(t: phase, dt: phaseIncrement)
        return raw
    }

    /// Square/pulse with PolyBLEP anti-aliasing at both edges.
    private func squareSample(phase: Float,
                               phaseIncrement: Float,
                               pulseWidth: Float) -> Float {
        var raw: Float = phase < pulseWidth ? 1.0 : -1.0
        raw += polyBLEP(t: phase, dt: phaseIncrement)
        raw -= polyBLEP(t: fmod(phase - pulseWidth + 1.0, 1.0), dt: phaseIncrement)
        return raw
    }

    /// PolyBLEP residual for discontinuity smoothing.
    /// Reference: Valimaki & Pakarinen (2012), "Aliasing Reduction in Clipped Signals".
    private func polyBLEP(t: Float, dt: Float) -> Float {
        if t < dt {
            let x = t / dt - 1.0
            return -(x * x)
        } else if t > 1.0 - dt {
            let x = (t - 1.0) / dt + 1.0
            return x * x
        }
        return 0.0
    }
}
