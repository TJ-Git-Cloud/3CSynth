// SynthView.swift
// Shared (iOS + AUv3)
//
// The core synthesizer interface, reusable in both the standalone iOS app and
// the AUv3 plug-in window. Accepts a `SynthParameters` instance directly,
// making it host-agnostic.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - SynthView

/// Full synthesizer interface, safe to embed in both the iOS app and AUv3 host.
///
/// `isPlugin` adjusts layout and background treatment for the plug-in window.
public struct SynthView: View {

    @Bindable var parameters: SynthParameters
    let isPlugin: Bool

    @State private var selectedTab: SynthTab = .oscillators

    public init(parameters: SynthParameters, isPlugin: Bool = false) {
        self.parameters = parameters
        self.isPlugin = isPlugin
    }

    public var body: some View {
        ZStack {
            (isPlugin ? Color.synthBackground : Color.clear).ignoresSafeArea()

            VStack(spacing: 0) {
                if isPlugin {
                    pluginHeader
                }

                SynthTabPicker(selectedTab: $selectedTab)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                tabContent
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                Spacer()
            }
        }
    }

    // MARK: Plugin Header

    private var pluginHeader: some View {
        HStack {
            Text("3CSYNTH")
                .font(.synthTitle)
                .foregroundStyle(.white)
                .tracking(4)

            Spacer()

            // Master volume knob in header for quick access.
            KnobView(
                label: "Volume",
                value: Binding(
                    get: { Double(parameters.masterVolume) },
                    set: { parameters.masterVolume = Float($0) }
                ),
                range: 0...1
            )
            .frame(width: 44, height: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.synthSurface)
    }

    // MARK: Tabs

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .oscillators: OscillatorSection(parameters: parameters)
            case .filter:      FilterSection(parameters: parameters)
            case .envelopes:   EnvelopeSection(parameters: parameters)
            case .modulation:  ModulationSection(parameters: parameters)
            case .effects:     EffectsSection(parameters: parameters)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: selectedTab)
    }
}

// SynthTabPicker is defined in Shared/Views/DesignSystem.swift
