// Voice.swift
// 3CSynth
//
// A single polyphonic voice: two oscillators → filter → amplifier envelope.
// All methods called from the audio thread must remain allocation-free.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Accelerate

// MARK: - Voice

/// One monophonic note path through the synthesis chain.
///
/// A `Voice` is stateful and mutable. The engine owns a fixed pool of `Voice`
/// objects that are reused across notes, so `start(note:frequency:amplitude:parameters:)`
/// resets all internal state before beginning a new note.
final class Voice {

    // MARK: State

    /// MIDI note number currently playing (0 if none).
    private(set) var currentNote: UInt8 = 0

    /// True while the voice is producing audio (including release tail).
    private(set) var isActive: Bool = false

    /// Monotonically increasing tick counter used for voice stealing (oldest-wins).
    private(set) var age: UInt64 = 0
    private static var globalAge: UInt64 = 0

    // MARK: DSP Components

    private var oscillator1: HybridOscillator
    private var oscillator2: HybridOscillator
    private var filter: StateVariableFilter
    private var ampEnvelope: ADSREnvelope
    private var filterEnvelope: ADSREnvelope
    private var lfo1: LFO

    // MARK: Per-Voice Modulators

    private var baseFrequency: Float = 440
    private var pitchBend: Float = 0       // in semitones
    private var modulation: Float = 0
    private var amplitude: Float = 1

    // Per-voice render scratch buffer avoids allocations on the audio thread.
    private var scratchL: [Float]
    private let maxFrames = 4096

    // MARK: Init

    init() {
        oscillator1     = HybridOscillator()
        oscillator2     = HybridOscillator()
        filter          = StateVariableFilter()
        ampEnvelope     = ADSREnvelope()
        filterEnvelope  = ADSREnvelope()
        lfo1            = LFO()
        scratchL        = [Float](repeating: 0, count: maxFrames)
    }

    // MARK: Configuration

    func configure(sampleRate: Double) {
        oscillator1.sampleRate    = sampleRate
        oscillator2.sampleRate    = sampleRate
        filter.sampleRate         = sampleRate
        ampEnvelope.sampleRate    = sampleRate
        filterEnvelope.sampleRate = sampleRate
        lfo1.sampleRate           = sampleRate
    }

    // MARK: Note Lifecycle

    /// Resets DSP state and begins a new note.
    func start(note: UInt8,
               frequency: Float,
               amplitude: Float,
               parameters: SynthParameters) {

        currentNote   = note
        baseFrequency = frequency
        self.amplitude = amplitude
        pitchBend     = 0
        modulation    = 0

        // Snapshot parameters at note-on time.
        oscillator1.waveform   = parameters.osc1Waveform
        oscillator1.detune     = parameters.osc1Detune
        oscillator1.octave     = parameters.osc1Octave
        oscillator1.level      = parameters.osc1Level
        oscillator1.wavetableIndex = parameters.osc1WavetableIndex

        oscillator2.waveform   = parameters.osc2Waveform
        oscillator2.detune     = parameters.osc2Detune
        oscillator2.octave     = parameters.osc2Octave
        oscillator2.level      = parameters.osc2Level
        oscillator2.wavetableIndex = parameters.osc2WavetableIndex

        filter.cutoff     = parameters.filterCutoff
        filter.resonance  = parameters.filterResonance
        filter.filterMode = parameters.filterMode

        ampEnvelope.attack  = parameters.ampAttack
        ampEnvelope.decay   = parameters.ampDecay
        ampEnvelope.sustain = parameters.ampSustain
        ampEnvelope.release = parameters.ampRelease

        filterEnvelope.attack  = parameters.filterEnvAttack
        filterEnvelope.decay   = parameters.filterEnvDecay
        filterEnvelope.sustain = parameters.filterEnvSustain
        filterEnvelope.release = parameters.filterEnvRelease

        lfo1.rate      = parameters.lfo1Rate
        lfo1.waveform  = parameters.lfo1Waveform
        lfo1.depth     = parameters.lfo1Depth

        // Set oscillator frequencies.
        updateFrequencies()

        filter.reset()
        ampEnvelope.noteOn()
        filterEnvelope.noteOn()
        lfo1.reset()

        isActive = true
        age = Voice.nextAge()
    }

    /// Begins the release phase; voice becomes inactive once envelope reaches zero.
    func release() {
        ampEnvelope.noteOff()
        filterEnvelope.noteOff()
    }

    // MARK: Real-Time Modulators

    func setPitchBend(_ semitones: Float) {
        pitchBend = semitones * 2.0   // ±2 semitone range
        updateFrequencies()
    }

    func setModulation(_ value: Float) {
        modulation = value
        lfo1.depth = modulation * 0.5   // mod wheel → LFO vibrato depth
    }

    // MARK: Rendering

    /// Accumulates this voice's output into the provided stereo buffers.
    ///
    /// - Parameters:
    ///   - left:  Pointer to the left-channel accumulation buffer.
    ///   - right: Pointer to the right-channel accumulation buffer.
    ///   - frameCount: Number of frames to render (must be ≤ `maxFrames`).
    ///   - parameters: Live parameter snapshot (filter cutoff etc. may change).
    func render(left: UnsafeMutablePointer<Float>,
                right: UnsafeMutablePointer<Float>,
                frameCount: Int,
                parameters: SynthParameters) {

        guard isActive, frameCount > 0 else { return }

        // Update dynamic parameters (may be automated by host).
        filter.cutoff    = parameters.filterCutoff
        filter.resonance = parameters.filterResonance
        lfo1.rate        = parameters.lfo1Rate

        let n = min(frameCount, maxFrames)

        // --- LFO pitch modulation: update frequencies before rendering ---
        let lfoValue = lfo1.nextSample()
        let pitchFactor = pow(2.0, lfoValue / 12.0)
        let bendFactor  = pitchBendFactor()
        let modBase = baseFrequency * pitchFactor * bendFactor
        oscillator1.frequency = modBase
        oscillator2.frequency = oscillator2.detuneFrequency(base: modBase)

        // Zero scratch buffer.
        scratchL.withUnsafeMutableBufferPointer { buf in
            vDSP_vclr(buf.baseAddress!, 1, vDSP_Length(n))
        }

        // --- Oscillators ---
        oscillator1.render(into: &scratchL, frameCount: n)
        oscillator2.render(into: &scratchL, frameCount: n)  // summed

        // --- Filter envelope modulation ---
        let filterEnvValue = filterEnvelope.nextSample()
        let modulatedCutoff = (parameters.filterCutoff + filterEnvValue * parameters.filterEnvAmount)
            .clamped(to: 20...20_000)
        filter.cutoff = modulatedCutoff

        // --- Filter ---
        filter.process(buffer: &scratchL, frameCount: n)

        // --- Amp envelope ---
        for i in 0 ..< n {
            let envSample = ampEnvelope.nextSample()
            scratchL[i] *= envSample * amplitude
        }

        // Deactivate voice once the amp envelope is fully silent.
        if ampEnvelope.isComplete {
            isActive = false
        }

        // Stereo spread: osc2 panning for width.
        let width = parameters.stereoWidth
        let leftGain  = Float(1.0 - width * 0.3)
        let rightGain = Float(1.0 + width * 0.3)

        // Accumulate into output buffers.
        scratchL.withUnsafeMutableBufferPointer { buf in
            var lg = leftGain
            var rg = rightGain
            vDSP_vsma(buf.baseAddress!, 1, &lg, left,  1, left,  1, vDSP_Length(n))
            vDSP_vsma(buf.baseAddress!, 1, &rg, right, 1, right, 1, vDSP_Length(n))
        }
    }

    // MARK: Private Helpers

    private func updateFrequencies() {
        let factor = pitchBendFactor()
        oscillator1.frequency = baseFrequency * factor
        oscillator2.frequency = oscillator2.detuneFrequency(base: baseFrequency * factor)
    }

    private func pitchBendFactor() -> Float {
        pow(2.0, pitchBend / 12.0)
    }

    private static func nextAge() -> UInt64 {
        globalAge &+= 1
        return globalAge
    }
}

// MARK: - Comparable Clamping

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
