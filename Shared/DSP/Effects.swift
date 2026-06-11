// Effects.swift
// 3CSynth
//
// Stereo delay and algorithmic reverb (Freeverb-inspired) for the synth engine.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Foundation

// MARK: - StereoDelay

/// Stereo feedback delay with configurable time, feedback, and wet/dry mix.
struct StereoDelay {

    var delayTime: Float = 0.25   // seconds
    var feedback:  Float = 0.3    // 0…0.95
    var mix:       Float = 0.0    // 0 = dry, 1 = fully wet
    var sampleRate: Double = k3CSynthDefaultSampleRate

    private var bufL: [Float]
    private var bufR: [Float]
    private var writePos = 0

    private static let capacity = Int(2.0 * 48_001)   // 2 s at 48 kHz

    init() {
        bufL = [Float](repeating: 0, count: StereoDelay.capacity)
        bufR = [Float](repeating: 0, count: StereoDelay.capacity)
    }

    mutating func process(left: UnsafeMutablePointer<Float>,
                          right: UnsafeMutablePointer<Float>,
                          frameCount: Int) {
        guard mix > 0.001 else { return }

        let delaySamples = max(1, min(Int(delayTime * Float(sampleRate)),
                                     StereoDelay.capacity - 1))
        let wet = mix
        let dry = 1.0 - wet

        for i in 0 ..< frameCount {
            let rp = (writePos - delaySamples + StereoDelay.capacity) % StereoDelay.capacity
            let dL = bufL[rp]
            let dR = bufR[rp]

            bufL[writePos] = left[i]  + dL * feedback
            bufR[writePos] = right[i] + dR * feedback

            left[i]  = left[i]  * dry + dL * wet
            right[i] = right[i] * dry + dR * wet

            writePos = (writePos + 1) % StereoDelay.capacity
        }
    }
}

// MARK: - CombFilter

private struct CombFilter {
    private var buf: [Float]
    private var pos = 0
    var feedback: Float
    private var filterState: Float = 0
    private let damp: Float = 0.5

    init(delay: Int, feedback: Float) {
        buf = [Float](repeating: 0, count: max(delay, 2))
        self.feedback = feedback
    }

    mutating func tick(_ input: Float) -> Float {
        let out = buf[pos]
        filterState = out * (1.0 - damp) + filterState * damp
        buf[pos] = input + filterState * feedback
        pos = (pos + 1) % buf.count
        return out
    }
}

// MARK: - AllpassFilter

private struct AllpassFilter {
    private var buf: [Float]
    private var pos = 0
    private let feedback: Float = 0.5

    init(delay: Int) {
        buf = [Float](repeating: 0, count: max(delay, 2))
    }

    mutating func tick(_ input: Float) -> Float {
        let buffered = buf[pos]
        let output   = -input + buffered
        buf[pos]     = input + buffered * feedback
        pos = (pos + 1) % buf.count
        return output
    }
}

// MARK: - SimpleReverb

/// Algorithmic stereo reverb using 8 parallel comb filters + 4 series allpass
/// per channel (Freeverb / Schroeder topology).
struct SimpleReverb {

    var mix: Float = 0.0

    private static let combDelays   = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let apDelays     = [556, 441, 341, 225]
    private static let stereoOffset = 23
    private static let combFeedback: Float = 0.84

    private var combsL: [CombFilter]
    private var combsR: [CombFilter]
    private var apL:    [AllpassFilter]
    private var apR:    [AllpassFilter]

    init(sampleRate: Double = k3CSynthDefaultSampleRate) {
        let scale = sampleRate / 44_100.0
        let fb    = SimpleReverb.combFeedback
        let ss    = SimpleReverb.stereoOffset

        combsL = SimpleReverb.combDelays.map { CombFilter(delay: Int(Double($0) * scale),        feedback: fb) }
        combsR = SimpleReverb.combDelays.map { CombFilter(delay: Int(Double($0 + ss) * scale),   feedback: fb) }
        apL    = SimpleReverb.apDelays.map   { AllpassFilter(delay: Int(Double($0) * scale)) }
        apR    = SimpleReverb.apDelays.map   { AllpassFilter(delay: Int(Double($0 + ss) * scale)) }
    }

    mutating func process(left: UnsafeMutablePointer<Float>,
                          right: UnsafeMutablePointer<Float>,
                          frameCount: Int) {
        guard mix > 0.001 else { return }

        let dry:     Float = 1.0 - mix
        let wetGain: Float = mix * 3.0

        for i in 0 ..< frameCount {
            let input = (left[i] + right[i]) * 0.015

            var outL: Float = 0
            var outR: Float = 0

            for j in 0 ..< combsL.count {
                outL += combsL[j].tick(input)
                outR += combsR[j].tick(input)
            }
            for j in 0 ..< apL.count {
                outL = apL[j].tick(outL)
                outR = apR[j].tick(outR)
            }

            left[i]  = left[i]  * dry + outL * wetGain
            right[i] = right[i] * dry + outR * wetGain
        }
    }
}
