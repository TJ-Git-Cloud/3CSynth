// EffectsSection.swift
// 3CSynthIOS
//
// Reverb and delay effects panel.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - EffectsSection

struct EffectsSection: View {

    @Bindable var parameters: SynthParameters

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // --- Reverb ---
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.synthBlue)
                    Text("REVERB")
                        .font(.synthSectionTitle)
                        .foregroundStyle(.synthBlue)
                }

                KnobView(
                    label: "Mix",
                    value: Binding(
                        get: { Double(parameters.reverbMix) },
                        set: { parameters.reverbMix = Float($0) }
                    ),
                    range: 0...1,
                    accentColor: .synthBlue
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Color.synthDivider)

            // --- Delay ---
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "repeat")
                        .foregroundStyle(.synthCyan)
                    Text("DELAY")
                        .font(.synthSectionTitle)
                        .foregroundStyle(.synthCyan)
                }

                HStack(spacing: 14) {
                    KnobView(
                        label: "Time",
                        value: Binding(
                            get: { Double(parameters.delayTime) },
                            set: { parameters.delayTime = Float($0) }
                        ),
                        range: 0.01...2,
                        unitSuffix: "s",
                        accentColor: .synthCyan
                    )

                    KnobView(
                        label: "Feedback",
                        value: Binding(
                            get: { Double(parameters.delayFeedback) },
                            set: { parameters.delayFeedback = Float($0) }
                        ),
                        range: 0...0.95,
                        accentColor: .synthCyan
                    )

                    KnobView(
                        label: "Mix",
                        value: Binding(
                            get: { Double(parameters.delayMix) },
                            set: { parameters.delayMix = Float($0) }
                        ),
                        range: 0...1,
                        accentColor: .synthCyan
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .synthSectionStyle()
    }
}
