// Filter.swift
// 3CSynth
//
// Two-pole State Variable Filter with simultaneous low-pass, high-pass,
// and band-pass outputs. Topology preserving transformation (TPT) formulation
// after Zavalishin (2012) "The Art of VA Filter Design".
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Accelerate
import Foundation

// MARK: - FilterMode

/// The response mode of the ``StateVariableFilter``.
public enum FilterMode: Int, CaseIterable, Identifiable, Sendable {
    case lowPass   = 0
    case bandPass  = 1
    case highPass  = 2
    case notch     = 3

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .lowPass:  return "Low Pass"
        case .bandPass: return "Band Pass"
        case .highPass: return "High Pass"
        case .notch:    return "Notch"
        }
    }
}

// MARK: - StateVariableFilter

/// Zero-delay-feedback (ZDF) state variable filter.
///
/// The SVF topology provides numerical stability at high resonance values
/// and allows simultaneous LP/BP/HP outputs without recalculating state,
/// making it ideal for real-time synthesis.
///
/// **Thread Safety**: Not thread-safe. Each ``Voice`` maintains its own
/// `StateVariableFilter` instance.
struct StateVariableFilter {

    // MARK: Parameters

    /// Cutoff frequency in Hz. Valid range: 20…20 000.
    var cutoff: Float = 1_000 {
        didSet { isDirty = true }
    }

    /// Resonance (Q). Range 0.1…20; values above ~0.7 produce self-oscillation.
    var resonance: Float = 0.5 {
        didSet { isDirty = true }
    }

    /// Active output mode.
    var filterMode: FilterMode = .lowPass

    var sampleRate: Double = k3CSynthDefaultSampleRate {
        didSet { isDirty = true }
    }

    // MARK: Internal State

    /// First integrator state.
    private var s1: Float = 0
    /// Second integrator state.
    private var s2: Float = 0

    // Cached coefficients – recomputed only when parameters change.
    private var g: Float  = 0     // tan(π f / fs)
    private var k: Float  = 0     // damping = 1/Q
    private var a1: Float = 0
    private var a2: Float = 0
    private var a3: Float = 0
    private var isDirty: Bool = true

    // MARK: Processing

    /// Processes `frameCount` samples in-place using `buffer`.
    mutating func process(buffer: inout [Float], frameCount: Int) {
        if isDirty { updateCoefficients() }

        for i in 0 ..< frameCount {
            let (lp, bp, hp) = tick(input: buffer[i])
            switch filterMode {
            case .lowPass:  buffer[i] = lp
            case .bandPass: buffer[i] = bp
            case .highPass: buffer[i] = hp
            case .notch:    buffer[i] = lp + hp
            }
        }
    }

    /// Processes a single sample and returns all three simultaneous outputs.
    @inline(__always)
    private mutating func tick(input: Float) -> (lp: Float, bp: Float, hp: Float) {
        let hp = (input - k * s1 - s2) * a1
        let bp = g * hp + s1
        let lp = g * bp + s2

        // Update integrator states.
        s1 = 2 * bp - s1   // 2 * bp_output - previous s1
        s2 = 2 * lp - s2

        return (lp, bp, hp)
    }

    // MARK: Coefficient Update

    private mutating func updateCoefficients() {
        let clampedCutoff = cutoff.clamped(to: 20 ... Float(sampleRate / 2.1))
        let clampedRes    = resonance.clamped(to: 0.1 ... 20.0)

        g  = tan(.pi * clampedCutoff / Float(sampleRate))
        k  = 1.0 / clampedRes
        a1 = 1.0 / (1.0 + g * (g + k))
        a2 = g * a1
        a3 = g * a2
        isDirty = false
    }

    /// Resets filter memory (call at voice start to avoid clicks).
    mutating func reset() {
        s1 = 0
        s2 = 0
    }
}

// MARK: - Clamped Helper

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
