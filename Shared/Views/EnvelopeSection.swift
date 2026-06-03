// EnvelopeSection.swift
// 3CSynthIOS
//
// Amplifier envelope parameter panel with live ADSR shape preview.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - EnvelopeSection

struct EnvelopeSection: View {

    @Bindable var parameters: SynthParameters

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("AMP ENVELOPE")
                .font(.synthSectionTitle)
                .foregroundStyle(.synthOrange)

            // Live ADSR shape
            EnvelopeShapeView(
                attack:  parameters.ampAttack,
                decay:   parameters.ampDecay,
                sustain: parameters.ampSustain,
                release: parameters.ampRelease,
                color:   .synthOrange
            )
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Knob row
            ADSRKnobRow(
                attack:  $parameters.ampAttack,
                decay:   $parameters.ampDecay,
                sustain: $parameters.ampSustain,
                release: $parameters.ampRelease,
                accentColor: .synthOrange
            )
        }
        .synthSectionStyle()
    }
}

// MARK: - EnvelopeShapeView

/// Renders an ADSR envelope curve using SwiftUI Canvas.
struct EnvelopeShapeView: View {
    var attack: Float
    var decay: Float
    var sustain: Float
    var release: Float
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let path = adsr(in: size)

            // Fill
            var filled = path
            filled.addLine(to: CGPoint(x: size.width * 0.8 + size.width * 0.2, y: size.height))
            filled.addLine(to: CGPoint(x: 0, y: size.height))
            filled.closeSubpath()
            ctx.fill(filled, with: .color(color.opacity(0.15)))

            // Stroke
            ctx.stroke(path, with: .color(color.opacity(0.9)), lineWidth: 1.8)
        }
        .background(Color.synthSurface)
    }

    private func adsr(in size: CGSize) -> Path {
        let w = size.width, h = size.height
        let pad: CGFloat = 4

        // Time proportions (log-ish feel)
        let totalTime: Float = attack + decay + 0.3 + release   // 0.3 = sustain hold
        let attackEnd  = CGFloat(attack / totalTime) * (w * 0.7) + pad
        let decayEnd   = attackEnd + CGFloat(decay / totalTime) * (w * 0.7)
        let sustainEnd = decayEnd + CGFloat(0.3 / totalTime) * (w * 0.7)
        let sustainY   = pad + (1.0 - CGFloat(sustain)) * (h - pad * 2)

        var path = Path()
        path.move(to: CGPoint(x: pad, y: h - pad))
        path.addCurve(
            to: CGPoint(x: attackEnd, y: pad),
            control1: CGPoint(x: pad + (attackEnd - pad) * 0.4, y: h - pad),
            control2: CGPoint(x: attackEnd * 0.9, y: pad + 4)
        )
        path.addCurve(
            to: CGPoint(x: decayEnd, y: sustainY),
            control1: CGPoint(x: attackEnd + (decayEnd - attackEnd) * 0.2, y: pad),
            control2: CGPoint(x: decayEnd * 0.9, y: sustainY - 4)
        )
        path.addLine(to: CGPoint(x: sustainEnd, y: sustainY))
        path.addCurve(
            to: CGPoint(x: w - pad, y: h - pad),
            control1: CGPoint(x: sustainEnd + 4, y: sustainY),
            control2: CGPoint(x: w - pad - 8, y: h - pad - 8)
        )
        return path
    }
}

// MARK: - ADSRKnobRow

/// Reusable ADSR knob row used in both amp and filter envelope panels.
struct ADSRKnobRow: View {
    @Binding var attack: Float
    @Binding var decay: Float
    @Binding var sustain: Float
    @Binding var release: Float
    var accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            KnobView(
                label: "A",
                value: Binding(
                    get: { Double(attack) },
                    set: { attack = Float($0) }
                ),
                range: 0.001...10,
                unitSuffix: "s",
                scaling: .logarithmic,
                accentColor: accentColor
            )
            KnobView(
                label: "D",
                value: Binding(
                    get: { Double(decay) },
                    set: { decay = Float($0) }
                ),
                range: 0.001...10,
                unitSuffix: "s",
                scaling: .logarithmic,
                accentColor: accentColor
            )
            KnobView(
                label: "S",
                value: Binding(
                    get: { Double(sustain) },
                    set: { sustain = Float($0) }
                ),
                range: 0...1,
                accentColor: accentColor
            )
            KnobView(
                label: "R",
                value: Binding(
                    get: { Double(release) },
                    set: { release = Float($0) }
                ),
                range: 0.001...15,
                unitSuffix: "s",
                scaling: .logarithmic,
                accentColor: accentColor
            )
        }
    }
}
