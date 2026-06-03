// LFO.swift
// 3CSynth
//
// Low-Frequency Oscillator for modulation (vibrato, filter sweep, tremolo).
// Runs at audio rate for precision at low frequencies.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Foundation

// MARK: - LFOWaveform

/// Available LFO shapes.
public enum LFOWaveform: Int, CaseIterable, Identifiable, Sendable {
    case sine     = 0
    case triangle = 1
    case sawtooth = 2
    case square   = 3
    case random   = 4   // Sample-and-hold

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .sine:     return "Sine"
        case .triangle: return "Triangle"
        case .sawtooth: return "Sawtooth"
        case .square:   return "Square"
        case .random:   return "S&H"
        }
    }
}

// MARK: - LFO

/// Audio-rate LFO with phase accumulation.
///
/// Output is in the range –1.0 … +1.0 before depth scaling.
/// For pitch modulation (vibrato) the engine maps the output to semitones.
struct LFO {

    // MARK: Parameters

    /// Rate in Hz. Typical range 0.1 … 20.
    var rate: Float = 1.0

    /// Modulation depth, scaling output by 0.0 … 1.0.
    var depth: Float = 0.5

    var waveform: LFOWaveform = .sine
    var sampleRate: Double = k3CSynthDefaultSampleRate

    // MARK: State

    private var phase: Float = 0
    private var lastRandomValue: Float = 0
    private var samplesSinceHold: Int = 0

    // MARK: Public API

    /// Resets the LFO phase (call at voice start for phase-sync behaviour).
    mutating func reset() {
        phase = 0
        lastRandomValue = 0
        samplesSinceHold = 0
    }

    /// Returns the next modulation sample scaled by `depth`.
    @inline(__always)
    mutating func nextSample() -> Float {
        let raw = rawSample()
        advance()
        return raw * depth
    }

    // MARK: Private

    private mutating func rawSample() -> Float {
        switch waveform {
        case .sine:
            return sin(phase * 2.0 * .pi)

        case .triangle:
            let t = phase < 0.5 ? phase : 1.0 - phase
            return 4.0 * t - 1.0

        case .sawtooth:
            return 2.0 * phase - 1.0

        case .square:
            return phase < 0.5 ? 1.0 : -1.0

        case .random:
            let samplesPerCycle = Int(Float(sampleRate) / max(rate, 0.001))
            if samplesSinceHold >= samplesPerCycle {
                lastRandomValue = Float.random(in: -1...1)
                samplesSinceHold = 0
            }
            samplesSinceHold += 1
            return lastRandomValue
        }
    }

    private mutating func advance() {
        phase += rate / Float(sampleRate)
        if phase >= 1.0 { phase -= 1.0 }
    }
}
