// ThreeCSynthApp.swift
// 3CSynthIOS
//
// iOS application entry point.
// Bootstraps the audio engine and injects shared state into the SwiftUI
// environment so all child views share the same parameter store.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AVFoundation
import SwiftUI

// MARK: - ThreeCSynthApp

@main
struct ThreeCSynthApp: App {

    @State private var appModel = ThreeCSynthAppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - ThreeCSynthAppModel

/// Top-level application model: owns the audio session, engine, and parameters.
///
/// Marked `@Observable` so that any view can observe engine-level state
/// (e.g. whether audio is running) without prop-drilling.
@Observable
final class ThreeCSynthAppModel {

    // MARK: Public

    let engine = SynthEngine()
    var parameters: SynthParameters { engine.parameters }
    let presetManager = PresetManager()

    private(set) var isAudioRunning = false
    private let avEngine = AVAudioEngine()   // must be retained for the app's lifetime

    // MARK: Init

    init() {
        configureAudioSession()
        engine.configure(sampleRate: Double(AVAudioSession.sharedInstance().sampleRate))
        startAudioEngine()
    }

    // MARK: Private

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // `.playback` category gives low-latency output on iPhone/iPad.
            // `.allowBluetooth` enables AirPods, etc.
            try session.setCategory(.playback,
                                    mode: .default,
                                    options: [.allowBluetooth, .allowAirPlay])
            try session.setPreferredIOBufferDuration(0.005)   // ~5 ms
            try session.setActive(true)
        } catch {
            print("[3CSynth] Audio session configuration failed: \(error)")
        }
    }

    private func startAudioEngine() {
        let outputNode = avEngine.outputNode
        let outputFormat = outputNode.inputFormat(forBus: 0)
        engine.configure(sampleRate: outputFormat.sampleRate)

        // Capture the engine directly — avoids ARC traffic on the real-time thread.
        let engineRef = engine
        let sourceNode = AVAudioSourceNode(format: outputFormat) { _, _, frameCount, audioBufferList in
            engineRef.render(outputBufferList: audioBufferList, frameCount: frameCount)
            return noErr
        }

        avEngine.attach(sourceNode)
        avEngine.connect(sourceNode, to: outputNode, format: outputFormat)

        do {
            try avEngine.start()
            isAudioRunning = true
        } catch {
            print("[3CSynth] AVAudioEngine failed to start: \(error)")
        }
    }
}
