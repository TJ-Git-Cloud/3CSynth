// Envelope.swift
// 3CSynth
//
// Exponential ADSR envelope generator.
// Uses a pole-zero digital filter approximation for smooth,
// musical curves identical to classic analog designs.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Foundation

// MARK: - EnvelopeStage

/// Discrete stages of the ADSR envelope state machine.
private enum EnvelopeStage {
    case idle, attack, decay, sustain, release
}

// MARK: - ADSREnvelope

/// Exponential attack/decay/sustain/release envelope.
///
/// Each stage uses a first-order IIR filter with a time-constant derived
/// from the stage duration, producing the same "60% in one time-constant"
/// curve as an analogue RC circuit.
///
/// Output range: 0.0 … 1.0.
struct ADSREnvelope {

    // MARK: Parameters (in seconds)

    var attack:  Float = 0.005   // 5 ms default
    var decay:   Float = 0.2
    var sustain: Float = 0.7     // 0…1 level
    var release: Float = 0.4

    var sampleRate: Double = k3CSynthDefaultSampleRate

    // MARK: State

    private var stage: EnvelopeStage = .idle
    private var currentValue: Float = 0
    private var targetValue: Float = 0
    private var coefficient: Float = 0

    /// Returns `true` once the release stage reaches silence.
    var isComplete: Bool { stage == .idle }

    // MARK: Trigger

    /// Starts the attack stage.
    mutating func noteOn() {
        stage = .attack
        targetValue = 1.0
        coefficient = computeCoefficient(for: attack)
    }

    /// Begins the release stage from the current output level.
    mutating func noteOff() {
        guard stage != .idle else { return }
        stage = .release
        targetValue = 0.0
        coefficient = computeCoefficient(for: release)
    }

    // MARK: Rendering

    /// Returns the next output sample and advances the state machine.
    @inline(__always)
    mutating func nextSample() -> Float {
        switch stage {

        case .idle:
            return 0

        case .attack:
            currentValue = coefficient * (currentValue - targetValue) + targetValue
            if currentValue >= 0.999 {
                currentValue = 1.0
                stage = .decay
                targetValue = sustain
                coefficient = computeCoefficient(for: decay)
            }

        case .decay:
            currentValue = coefficient * (currentValue - targetValue) + targetValue
            if abs(currentValue - sustain) < 0.001 {
                currentValue = sustain
                stage = .sustain
            }

        case .sustain:
            currentValue = sustain   // Hold steady; noteOff transitions to release.

        case .release:
            currentValue = coefficient * currentValue   // target is 0
            if currentValue < 0.0001 {
                currentValue = 0
                stage = .idle
            }
        }

        return currentValue
    }

    // MARK: Private Helpers

    /// Returns the one-pole filter coefficient for a given time in seconds.
    /// Uses the standard RC time-constant formula: coeff = e^(–1 / (time * sr)).
    private func computeCoefficient(for time: Float) -> Float {
        guard time > 0 else { return 0 }
        return exp(-1.0 / (time * Float(sampleRate)))
    }
}
