// FilterSection.swift
// 3CSynthIOS
//
// Filter and filter envelope parameter panel.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - FilterSection

struct FilterSection: View {

    @Bindable var parameters: SynthParameters

    var body: some View {
        HStack(alignment: .top, spacing: 12) {

            // --- Filter Controls ---
            VStack(alignment: .leading, spacing: 10) {
                Text("FILTER")
                    .font(.synthSectionTitle)
                    .foregroundStyle(.synthGreen)

                // Mode picker
                FilterModePicker(selection: $parameters.filterMode)

                // Frequency response visualisation
                FilterResponseView(
                    cutoff: parameters.filterCutoff,
                    resonance: parameters.filterResonance,
                    mode: parameters.filterMode
                )
                .frame(height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Knobs
                HStack(spacing: 16) {
                    KnobView(
                        label: "Cutoff",
                        value: Binding(
                            get: { Double(parameters.filterCutoff) },
                            set: { parameters.filterCutoff = Float($0) }
                        ),
                        range: 20...20_000,
                        unitSuffix: "Hz",
                        scaling: .logarithmic,
                        accentColor: .synthGreen
                    )

                    KnobView(
                        label: "Res",
                        value: Binding(
                            get: { Double(parameters.filterResonance) },
                            set: { parameters.filterResonance = Float($0) }
                        ),
                        range: 0.1...20,
                        scaling: .logarithmic,
                        accentColor: .synthGreen
                    )

                    KnobView(
                        label: "Env Amt",
                        value: Binding(
                            get: { Double(parameters.filterEnvAmount) },
                            set: { parameters.filterEnvAmount = Float($0) }
                        ),
                        range: -10_000...10_000,
                        unitSuffix: "Hz",
                        accentColor: .synthGreen
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Color.synthDivider)

            // --- Filter Envelope ---
            VStack(alignment: .leading, spacing: 10) {
                Text("FILTER ENV")
                    .font(.synthSectionTitle)
                    .foregroundStyle(.synthGreen.opacity(0.7))

                EnvelopeShapeView(
                    attack: parameters.filterEnvAttack,
                    decay: parameters.filterEnvDecay,
                    sustain: parameters.filterEnvSustain,
                    release: parameters.filterEnvRelease,
                    color: .synthGreen.opacity(0.7)
                )
                .frame(height: 60)

                ADSRKnobRow(
                    attack:  $parameters.filterEnvAttack,
                    decay:   $parameters.filterEnvDecay,
                    sustain: $parameters.filterEnvSustain,
                    release: $parameters.filterEnvRelease,
                    accentColor: .synthGreen.opacity(0.7)
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .synthSectionStyle()
    }
}

// MARK: - FilterModePicker

private struct FilterModePicker: View {
    @Binding var selection: FilterMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FilterMode.allCases) { mode in
                Button {
                    withAnimation { selection = mode }
                } label: {
                    Text(modeLabel(mode))
                        .font(.synthCaption)
                        .foregroundStyle(selection == mode ? .synthBackground : .synthSecondaryLabel)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            selection == mode ? Color.synthGreen : Color.synthSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }

    private func modeLabel(_ mode: FilterMode) -> String {
        switch mode {
        case .lowPass:  return "LP"
        case .bandPass: return "BP"
        case .highPass: return "HP"
        case .notch:    return "NTC"
        }
    }
}

// MARK: - FilterResponseView

/// Stylised Bode-plot-like filter response curve.
private struct FilterResponseView: View {
    let cutoff: Float
    let resonance: Float
    let mode: FilterMode

    var body: some View {
        Canvas { ctx, size in
            let path = responsePath(in: size)
            ctx.stroke(path, with: .color(.synthGreen.opacity(0.8)), lineWidth: 1.5)

            // Fill under curve
            var filled = path
            filled.addLine(to: CGPoint(x: size.width, y: size.height))
            filled.addLine(to: CGPoint(x: 0, y: size.height))
            filled.closeSubpath()
            ctx.fill(filled, with: .color(.synthGreen.opacity(0.12)))
        }
        .background(Color.synthSurface)
    }

    private func responsePath(in size: CGSize) -> Path {
        let w = size.width, h = size.height
        let cutoffNorm = log10(Double(cutoff) / 20.0) / log10(1000.0)   // 0…1 log scale
        let cutoffX = cutoffNorm * Double(w)
        let resonancePeak = Double(resonance) / 20.0 * Double(h) * 0.6

        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.15))

        for x in stride(from: 0.0, through: w, by: 1.0) {
            let freq = 20.0 * pow(1000.0, x / Double(w))
            let y = responseY(freq: freq, h: Double(h), cutoffX: cutoffX,
                              resonancePeak: resonancePeak, width: Double(w), xPos: x)
            if x == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        return path
    }

    private func responseY(freq: Double, h: Double, cutoffX: Double,
                           resonancePeak: Double, width: Double, xPos: Double) -> Double {
        let dist = xPos - cutoffX
        let peak = resonancePeak * exp(-dist * dist / (width * 0.005))

        switch mode {
        case .lowPass:
            return xPos < cutoffX
                ? h * 0.15 - peak
                : h * 0.15 + (xPos - cutoffX) * (h * 0.65 / (width - cutoffX)) - peak
        case .highPass:
            return xPos > cutoffX
                ? h * 0.15 - peak
                : h * 0.15 + (cutoffX - xPos) * (h * 0.65 / cutoffX) - peak
        case .bandPass:
            return h * 0.15 + abs(xPos - cutoffX) * (h * 0.55 / (width * 0.5)) - peak
        case .notch:
            return h * 0.15 + peak * 2
        }
    }
}
