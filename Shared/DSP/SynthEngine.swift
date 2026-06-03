// SynthEngine.swift
// 3CSynth
//
// Core polyphonic synthesis engine.
// Manages voice allocation, MIDI event dispatch, and final audio mixing.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import Accelerate
import AVFoundation

// MARK: - Engine Configuration

/// Maximum simultaneous voices. Balances CPU headroom against playability.
public let k3CSynthMaxVoices: Int = 16

/// The sample rate assumed until the engine is configured by the host.
public let k3CSynthDefaultSampleRate: Double = 44_100

// MARK: - SynthEngine

/// Thread-safe, real-time–capable polyphonic synthesis engine.
///
/// `SynthEngine` owns a pool of ``Voice`` instances and dispatches incoming
/// MIDI note events to them using a simple "steal-oldest" voice-allocation
/// policy. All audio rendering happens inside ``render(outputBufferList:frameCount:)``
/// which is designed to be called from a real-time audio thread; no Swift
/// allocations or locks are performed on that path.
///
/// **Usage**
/// ```swift
/// let engine = SynthEngine()
/// engine.configure(sampleRate: 48_000)
/// engine.noteOn(note: 60, velocity: 100)
/// engine.render(outputBufferList: &abl, frameCount: 512)
/// engine.noteOff(note: 60)
/// ```
public final class SynthEngine {

    // MARK: Public Properties

    /// Live parameter state read by voices on every render cycle.
    public var parameters: SynthParameters

    // MARK: Private State

    private var voices: [Voice]
    private var sampleRate: Double
    private var pitchBend: Float = 0.0            // –1…+1 (±2 semitones)
    private var modWheel: Float = 0.0             // 0…1
    private var masterVolume: Float = 0.8

    private let maxFramesPerSlice: Int = 4096

    // MARK: Init

    public init() {
        sampleRate = k3CSynthDefaultSampleRate
        parameters = SynthParameters()

        voices = (0 ..< k3CSynthMaxVoices).map { _ in Voice() }
    }

    // MARK: Configuration

    /// Propagates a new sample rate to all voices and internal DSP components.
    public func configure(sampleRate newRate: Double) {
        sampleRate = newRate
        for voice in voices {
            voice.configure(sampleRate: newRate)
        }
    }

    // MARK: MIDI

    /// Starts a new note, stealing the oldest active voice if the pool is full.
    public func noteOn(note: UInt8, velocity: UInt8) {
        guard velocity > 0 else {
            noteOff(note: note)
            return
        }
        let voice = findAvailableVoice() ?? stealOldestVoice()
        let freq = midiNoteToFrequency(note)
        let amp = Float(velocity) / 127.0
        voice.start(note: note, frequency: freq, amplitude: amp, parameters: parameters)
    }

    /// Releases the voice playing `note`, allowing its envelope to decay.
    public func noteOff(note: UInt8) {
        for voice in voices where voice.currentNote == note && voice.isActive {
            voice.release()
        }
    }

    /// All-notes-off (MIDI CC 123).
    public func allNotesOff() {
        for voice in voices {
            voice.release()
        }
    }

    /// Updates pitch bend in the range –1.0 … +1.0 (±2 semitones by default).
    public func setPitchBend(_ value: Float) {
        pitchBend = value.clamped(to: -1...1)
        for voice in voices where voice.isActive {
            voice.setPitchBend(pitchBend)
        }
    }

    /// Sets modulation wheel (CC 1), 0.0 … 1.0.
    public func setModWheel(_ value: Float) {
        modWheel = value.clamped(to: 0...1)
        for voice in voices where voice.isActive {
            voice.setModulation(modWheel)
        }
    }

    // MARK: Rendering

    /// Renders `frameCount` frames of stereo audio into `outputBufferList`.
    ///
    /// This method is **real-time safe**: it performs no Swift allocations,
    /// acquires no locks, and makes no system calls.
    ///
    /// - Parameters:
    ///   - outputBufferList: A stereo (2-channel) `AudioBufferList`.
    ///   - frameCount: Number of sample frames to render (≤ `maxFramesPerSlice`).
    public func render(outputBufferList: UnsafeMutablePointer<AudioBufferList>,
                       frameCount: AUAudioFrameCount) {

        let abl = UnsafeMutableAudioBufferListPointer(outputBufferList)
        guard abl.count >= 2 else { return }

        let frames = Int(frameCount)

        // Silence the output buffers.
        for buffer in abl {
            guard let data = buffer.mData else { continue }
            memset(data, 0, Int(buffer.mDataByteSize))
        }

        guard let leftPtr = abl[0].mData?.assumingMemoryBound(to: Float.self),
              let rightPtr = abl[1].mData?.assumingMemoryBound(to: Float.self) else {
            return
        }

        // Sum active voices directly into the output buffers.
        for voice in voices where voice.isActive {
            voice.render(
                left: leftPtr,
                right: rightPtr,
                frameCount: frames,
                parameters: parameters
            )
        }

        // Apply master volume with vDSP for efficiency.
        var vol = masterVolume
        vDSP_vsmul(leftPtr,  1, &vol, leftPtr,  1, vDSP_Length(frames))
        vDSP_vsmul(rightPtr, 1, &vol, rightPtr, 1, vDSP_Length(frames))
    }

    // MARK: Private Helpers

    private func findAvailableVoice() -> Voice? {
        voices.first { !$0.isActive }
    }

    private func stealOldestVoice() -> Voice {
        // Steal the voice that has been active the longest.
        voices.min(by: { $0.age < $1.age }) ?? voices[0]
    }

    private func midiNoteToFrequency(_ note: UInt8) -> Float {
        440.0 * pow(2.0, (Float(note) - 69.0) / 12.0)
    }
}

// MARK: - Clamped Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
