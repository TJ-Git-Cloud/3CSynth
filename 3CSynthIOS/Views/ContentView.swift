// ContentView.swift
// 3CSynthIOS
//
// Root view of the 3CSynth iOS app.
// Lays out the synthesizer panel above a multi-touch keyboard.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - ContentView

/// The root view, composing all major sections of the synthesizer UI.
///
/// Layout strategy:
/// - On iPad (regular width): four-column horizontal panel + full-width keyboard.
/// - On iPhone (compact width): horizontally scrollable panel + keyboard.
struct ContentView: View {

    @Environment(ThreeCSynthAppModel.self) private var appModel
    @State private var selectedTab: SynthTab = .oscillators
    @State private var showPresets = false

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.synthBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav bar
                ThreeCSynthNavBar(showPresets: $showPresets)

                // Tab selector (compact) or full panel (regular)
                Group {
                    tabContent
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer(minLength: 4)

                // Piano keyboard always visible at the bottom.
                KeyboardView(engine: appModel.engine)
                    .frame(height: keyboardHeight)
                    .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showPresets) {
            PresetsView(
                presetManager: appModel.presetManager,
                parameters: appModel.parameters
            )
        }
    }

    // MARK: Tab Content

    @ViewBuilder
    private var tabContent: some View {
        VStack(spacing: 8) {
            // Section tab strip
            SynthTabPicker(selectedTab: $selectedTab)

            // Section content
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
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
    }

    private var keyboardHeight: CGFloat {
        UIDevice.current.userInterfaceIdiom == .pad ? 200 : 150
    }
}

// MARK: - ThreeCSynthNavBar

private struct ThreeCSynthNavBar: View {
    @Binding var showPresets: Bool

    var body: some View {
        HStack {
            Text("3CSYNTH")
                .font(.synthTitle)
                .foregroundStyle(.white)
                .tracking(4)

            Spacer()

            Button {
                showPresets = true
            } label: {
                Label("Presets", systemImage: "list.star")
                    .font(.synthCaption)
                    .foregroundStyle(.synthAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.synthSurface.shadow(.drop(color: .black.opacity(0.4), radius: 8)))
    }
}
