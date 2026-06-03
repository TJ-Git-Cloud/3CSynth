// WavetableBank.swift
// 3CSynth
//
// Pre-computed wavetable library with mip-map anti-aliasing.
// Tables are generated at startup and live for the application's lifetime.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Accelerate
import Foundation

// MARK: - WavetableBank

/// Singleton repository of bandlimited wavetables.
///
/// Each entry consists of a family of mip-map levels, one per octave range,
/// with progressively fewer harmonics to prevent aliasing at higher pitches.
/// Sample reads use linear interpolation between adjacent table entries.
///
/// Add custom waveforms by calling ``register(name:generator:)`` before the
/// first audio render.
public final class WavetableBank {

    // MARK: Shared Instance

    public static let shared = WavetableBank()

    // MARK: Constants

    /// Number of samples per wavetable (power-of-two for efficient wrapping).
    public static let tableSize: Int = 2048

    /// Number of mip-map levels (octave bands from 20 Hz up to ~Nyquist).
    private static let mipLevels: Int = 10

    // MARK: Storage

    private struct WavetableEntry {
        let name: String
        /// Mip-map levels: `mips[0]` is fullband, `mips[n]` has fewer harmonics.
        let mips: [[Float]]
    }

    private var entries: [WavetableEntry] = []

    // MARK: Init

    private init() {
        buildDefaultTables()
    }

    // MARK: Public API

    /// Number of registered wavetables.
    public var count: Int { entries.count }

    /// Display name for the wavetable at `index`.
    public func name(at index: Int) -> String {
        guard entries.indices.contains(index) else { return "—" }
        return entries[index].name
    }

    /// Reads a bandlimited sample from the wavetable at `tableIndex`.
    ///
    /// - Parameters:
    ///   - tableIndex: Wavetable index (wraps if out of range).
    ///   - phase:      Normalised playback position 0…1.
    ///   - frequency:  Oscillator frequency in Hz (used to select mip level).
    ///   - sampleRate: Host sample rate.
    public func sample(tableIndex: Int,
                       phase: Float,
                       frequency: Float,
                       sampleRate: Float) -> Float {

        guard !entries.isEmpty else { return 0 }
        let index = tableIndex % entries.count
        let entry = entries[index]
        let mipLevel = selectMipLevel(frequency: frequency, sampleRate: sampleRate)
        let table = entry.mips[mipLevel]
        return interpolatedSample(table: table, phase: phase)
    }

    /// Registers a custom wavetable with a unique name and a generator closure.
    ///
    /// The generator receives a normalised phase (0…1) and returns a sample.
    /// Anti-aliased mip-maps are computed automatically.
    public func register(name: String,
                         generator: (Float) -> Float) {

        let entry = buildEntry(name: name, generator: generator)
        entries.append(entry)
    }

    // MARK: Wavetable Construction

    private func buildDefaultTables() {
        // 1. Additive sawtooth (harmonic series)
        register(name: "Saw") { phase in
            var y: Float = 0
            for h in 1 ... 16 {
                y += sin(phase * 2.0 * .pi * Float(h)) / Float(h)
            }
            return y * (2.0 / .pi)
        }

        // 2. Additive square (odd harmonics)
        register(name: "Square") { phase in
            var y: Float = 0
            for h in stride(from: 1, through: 15, by: 2) {
                y += sin(phase * 2.0 * .pi * Float(h)) / Float(h)
            }
            return y * (4.0 / .pi)
        }

        // 3. Formant / vowel-like shape
        register(name: "Formant") { phase in
            let t = phase * 2.0 * .pi
            return sin(t) + 0.5 * sin(2 * t) + 0.3 * sin(3 * t) + 0.15 * sin(5 * t)
        }

        // 4. "Bright Pad" – steep harmonic rolloff
        register(name: "Bright Pad") { phase in
            let t = phase * 2.0 * .pi
            var y: Float = 0
            for h in 1 ... 12 {
                y += sin(t * Float(h)) / pow(Float(h), 1.5)
            }
            return y
        }

        // 5. PWM-style (asymmetric sine)
        register(name: "PWM") { phase in
            let duty: Float = 0.3
            return phase < duty ? sin(phase / duty * .pi) : -sin((phase - duty) / (1 - duty) * .pi)
        }

        // 6. Digital / gritty
        register(name: "Digital") { phase in
            let t = phase * 2.0 * .pi
            return sin(t) + 0.6 * sin(3 * t) + 0.4 * sin(5 * t) + 0.2 * sin(7 * t)
        }

        // 7. Sine (pure reference)
        register(name: "Sine") { phase in
            sin(phase * 2.0 * .pi)
        }
    }

    private func buildEntry(name: String, generator: (Float) -> Float) -> WavetableEntry {
        let size = WavetableBank.tableSize
        let levels = WavetableBank.mipLevels

        // Generate the fullband table.
        var fullband = (0 ..< size).map { i in
            generator(Float(i) / Float(size))
        }

        // Normalize to –1…+1.
        var maxAbs: Float = 0
        vDSP_maxmgv(fullband, 1, &maxAbs, vDSP_Length(size))
        if maxAbs > 0 {
            var scale = 1.0 / maxAbs
            vDSP_vsmul(fullband, 1, &scale, &fullband, 1, vDSP_Length(size))
        }

        // Build mip-map levels by progressively low-pass filtering.
        var mips: [[Float]] = [fullband]
        for _ in 1 ..< levels {
            let prev = mips.last!
            // Simple 2-tap averaging to halve bandwidth.
            var next = [Float](repeating: 0, count: size)
            for i in 0 ..< size {
                next[i] = (prev[i] + prev[(i + 1) % size]) * 0.5
            }
            mips.append(next)
        }

        return WavetableEntry(name: name, mips: mips)
    }

    // MARK: Mip Selection

    private func selectMipLevel(frequency: Float, sampleRate: Float) -> Int {
        // Choose mip level so that the fundamental is well below Nyquist.
        let nyquist = sampleRate / 2.0
        let ratio = nyquist / max(frequency, 1)
        let level = Int(log2(ratio))
        return level.clamped(to: 0 ... WavetableBank.mipLevels - 1)
    }

    // MARK: Interpolation

    private func interpolatedSample(table: [Float], phase: Float) -> Float {
        let size = Float(table.count)
        let floatIndex = phase * size
        let indexA = Int(floatIndex) % table.count
        let indexB = (indexA + 1) % table.count
        let fraction = floatIndex - floor(floatIndex)
        return table[indexA] + fraction * (table[indexB] - table[indexA])
    }
}

// MARK: - Clamped Helper

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
