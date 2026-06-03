// ThreeCSynthMacApp.swift
// 3CSynthMac
//
// macOS application entry point.
// Opens a single fixed-size synthesizer window backed by the same
// `SynthEngine` and `SynthParameters` used by the iOS app.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import AVFoundation
import SwiftUI

// MARK: - ThreeCSynthMacApp

@main
struct ThreeCSynthMacApp: App {

    @State private var appModel = ThreeCSynthMacAppModel()

    var body: some Scene {
        Window("3CSynth", id: "main") {
            MacContentView()
                .environment(appModel)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 960, height: 620)

        // Menu bar extras
        .commands {
            CommandGroup(replacing: .newItem) {}   // 3CSynth is single-window
            CommandMenu("Presets") {
                Button("Show Presets…") {
                    NotificationCenter.default.post(name: .synthShowPresets, object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - ThreeCSynthMacAppModel

/// macOS application model: owns the audio session and engine.
@Observable
final class ThreeCSynthMacAppModel {

    let engine      = SynthEngine()
    let parameters  = SynthParameters()
    let presets     = PresetManager()

    private(set) var isRunning = false
    private let avEngine = AVAudioEngine()   // must be retained for the app's lifetime

    init() {
        startAudio()
    }

    private func startAudio() {
        let avEngine = self.avEngine
        let outputNode = avEngine.outputNode
        let format = outputNode.inputFormat(forBus: 0)

        engine.configure(sampleRate: format.sampleRate)

        // Capture the engine directly — avoids ARC traffic on the real-time thread.
        let engineRef = engine
        let sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, abl in
            engineRef.render(outputBufferList: abl, frameCount: frameCount)
            return noErr
        }

        avEngine.attach(sourceNode)
        avEngine.connect(sourceNode, to: outputNode, format: format)

        do {
            try avEngine.start()
            isRunning = true
        } catch {
            print("[3CSynth Mac] Audio engine start failed: \(error)")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let synthShowPresets = Notification.Name("SynthShowPresets")
}
