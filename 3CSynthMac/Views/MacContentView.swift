// MacContentView.swift
// 3CSynthMac
//
// macOS root view. Uses a three-column layout suited to wider displays.
// The left column shows the preset browser, centre shows the synth panel,
// and an optional bottom strip holds a mini keyboard.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - MacContentView

struct MacContentView: View {

    @Environment(ThreeCSynthMacAppModel.self) private var appModel
    @State private var showPresets = false
    @State private var selectedTab: SynthTab = .oscillators

    var body: some View {
        VStack(spacing: 0) {

            // ── Title bar area ────────────────────────────────────────────
            macToolbar

            Divider().background(Color.synthDivider)

            // ── Main content ──────────────────────────────────────────────
            HStack(spacing: 0) {

                // Preset sidebar (toggleable)
                if showPresets {
                    macPresetSidebar
                        .frame(width: 200)
                    Divider().background(Color.synthDivider)
                }

                // Synth panel
                VStack(spacing: 0) {
                    SynthTabPicker(selectedTab: $selectedTab)
                        .padding(10)

                    Group {
                        switch selectedTab {
                        case .oscillators:
                            OscillatorSection(parameters: appModel.parameters)
                        case .filter:
                            FilterSection(parameters: appModel.parameters)
                        case .envelopes:
                            EnvelopeSection(parameters: appModel.parameters)
                        case .modulation:
                            ModulationSection(parameters: appModel.parameters)
                        case .effects:
                            EffectsSection(parameters: appModel.parameters)
                        }
                    }
                    .padding(12)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.15), value: selectedTab)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            Divider().background(Color.synthDivider)

            // ── Mini keyboard ─────────────────────────────────────────────
            MacMiniKeyboard(engine: appModel.engine)
                .frame(height: 100)
        }
        .background(Color.synthBackground)
        .onReceive(NotificationCenter.default.publisher(for: .synthShowPresets)) { _ in
            withAnimation { showPresets.toggle() }
        }
    }

    // MARK: Toolbar

    private var macToolbar: some View {
        HStack(spacing: 12) {
            Text("3CSYNTH")
                .font(.synthTitle)
                .foregroundStyle(.white)
                .tracking(4)

            Spacer()

            // Master volume
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.3")
                    .foregroundStyle(.synthSecondaryLabel)
                    .font(.system(size: 11))

                Slider(
                    value: Binding(
                        get: { Double(appModel.parameters.masterVolume) },
                        set: { appModel.parameters.masterVolume = Float($0) }
                    ),
                    in: 0...1
                )
                .frame(width: 100)
                .tint(.synthAccent)
            }

            Divider().frame(height: 16)

            // Preset browser toggle
            Button {
                withAnimation { showPresets.toggle() }
            } label: {
                Label("Presets", systemImage: showPresets ? "sidebar.left" : "sidebar.left")
                    .font(.system(size: 12))
                    .foregroundStyle(showPresets ? .synthAccent : .synthSecondaryLabel)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.synthSurface)
    }

    // MARK: Preset Sidebar

    private var macPresetSidebar: some View {
        VStack(spacing: 0) {
            Text("Presets")
                .font(.synthSectionTitle)
                .foregroundStyle(.synthSecondaryLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            Divider().background(Color.synthDivider)

            List {
                ForEach(PresetCategory.allCases, id: \.self) { cat in
                    Section(cat.rawValue) {
                        let presets = appModel.presets.factoryPresets.filter { $0.category == cat }
                        ForEach(presets) { preset in
                            Button {
                                withAnimation {
                                    appModel.parameters.apply(preset)
                                }
                            } label: {
                                Text(preset.name)
                                    .font(.synthCaption)
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.sidebar)
        }
        .background(Color.synthSurface)
    }
}

// MARK: - MacMiniKeyboard

/// A simplified keyboard for the macOS app using AppKit event monitoring.
struct MacMiniKeyboard: NSViewRepresentable {

    let engine: SynthEngine

    func makeNSView(context: Context) -> MacKeyboardNSView {
        let view = MacKeyboardNSView()
        view.engine = engine
        return view
    }

    func updateNSView(_ nsView: MacKeyboardNSView, context: Context) {
        nsView.engine = engine
    }
}

// MARK: - MacKeyboardNSView

/// NSView-based piano keyboard for macOS.
final class MacKeyboardNSView: NSView {

    var engine: SynthEngine?
    var baseNote: UInt8 = 48
    private var activeNotes: Set<UInt8> = []
    private let visibleWhiteKeys = 21

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard NSGraphicsContext.current != nil else { return }
        let w = bounds.width / CGFloat(visibleWhiteKeys)
        let h = bounds.height
        let blackH = h * 0.60
        let blackW = w * 0.58

        // White keys
        for i in 0 ..< visibleWhiteKeys {
            let note = whiteNoteAt(index: i)
            let x = CGFloat(i) * w
            let rect = CGRect(x: x + 0.5, y: 0, width: w - 1, height: h)
            let isActive = activeNotes.contains(note)
            let color = isActive ? NSColor(red: 0.7, green: 0.7, blue: 1, alpha: 1) : NSColor.white
            color.setFill()
            let path = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
            path.fill()
        }

        // Black keys
        for i in 0 ..< visibleWhiteKeys {
            guard let black = blackNoteAbove(whiteIndex: i) else { continue }
            let x = CGFloat(i) * w + w - blackW / 2
            let rect = CGRect(x: x, y: h - blackH, width: blackW, height: blackH)
            let isActive = activeNotes.contains(black)
            (isActive ? NSColor(red: 0.35, green: 0.35, blue: 0.9, alpha: 1) : NSColor(white: 0.12, alpha: 1)).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2, yRadius: 2).fill()
        }
    }

    override func mouseDown(with event: NSEvent) {
        becomeFirstResponder()
        if let note = note(for: event) { press(note) }
    }

    override func mouseDragged(with event: NSEvent) {
        // Simple: release all and press new
        releaseAll()
        if let note = note(for: event) { press(note) }
    }

    override func mouseUp(with event: NSEvent) {
        releaseAll()
    }

    private func press(_ note: UInt8) {
        engine?.noteOn(note: note, velocity: 90)
        activeNotes.insert(note)
        setNeedsDisplay(bounds)
    }

    private func releaseAll() {
        activeNotes.forEach { engine?.noteOff(note: $0) }
        activeNotes.removeAll()
        setNeedsDisplay(bounds)
    }

    private func note(for event: NSEvent) -> UInt8? {
        let pt = convert(event.locationInWindow, from: nil)
        let w = bounds.width / CGFloat(visibleWhiteKeys)
        let blackH = bounds.height * 0.60
        let blackW = w * 0.58

        for i in 0 ..< visibleWhiteKeys {
            guard let black = blackNoteAbove(whiteIndex: i) else { continue }
            let x = CGFloat(i) * w + w - blackW / 2
            let rect = CGRect(x: x, y: bounds.height - blackH, width: blackW, height: blackH)
            if rect.contains(pt) { return black }
        }
        for i in 0 ..< visibleWhiteKeys {
            let x = CGFloat(i) * w
            let rect = CGRect(x: x, y: 0, width: w, height: bounds.height)
            if rect.contains(pt) { return whiteNoteAt(index: i) }
        }
        return nil
    }

    private func whiteNoteAt(index: Int) -> UInt8 {
        let degrees = [0, 2, 4, 5, 7, 9, 11]
        let octave  = index / 7
        let degree  = degrees[index % 7]
        return UInt8(clamping: Int(baseNote) + octave * 12 + degree)
    }

    private func blackNoteAbove(whiteIndex: Int) -> UInt8? {
        let noBlack: Set<Int> = [2, 6]
        guard !noBlack.contains(whiteIndex % 7) else { return nil }
        return UInt8(clamping: Int(whiteNoteAt(index: whiteIndex)) + 1)
    }
}
