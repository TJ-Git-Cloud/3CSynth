// ModulationSection.swift
// 3CSynthIOS
//
// LFO and modulation routing panel.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - ModulationSection

struct ModulationSection: View {

    @Bindable var parameters: SynthParameters

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LFO 1")
                .font(.synthSectionTitle)
                .foregroundStyle(.synthPurple)

            HStack(alignment: .top, spacing: 20) {

                // Waveform picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Shape")
                        .font(.synthCaption)
                        .foregroundStyle(.synthSecondaryLabel)

                    LFOWaveformPicker(selection: $parameters.lfo1Waveform)
                }

                Spacer()

                // LFO oscilloscope preview
                LFOPreviewView(waveform: parameters.lfo1Waveform,
                               rate: parameters.lfo1Rate,
                               depth: parameters.lfo1Depth)
                    .frame(width: 80, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Spacer()

                // Rate + Depth knobs
                HStack(spacing: 14) {
                    KnobView(
                        label: "Rate",
                        value: Binding(
                            get: { Double(parameters.lfo1Rate) },
                            set: { parameters.lfo1Rate = Float($0) }
                        ),
                        range: 0.1...20,
                        unitSuffix: "Hz",
                        scaling: .logarithmic,
                        accentColor: .synthPurple
                    )

                    KnobView(
                        label: "Depth",
                        value: Binding(
                            get: { Double(parameters.lfo1Depth) },
                            set: { parameters.lfo1Depth = Float($0) }
                        ),
                        range: 0...1,
                        accentColor: .synthPurple
                    )
                }
            }
        }
        .synthSectionStyle()
    }
}

// MARK: - LFOWaveformPicker

private struct LFOWaveformPicker: View {
    @Binding var selection: LFOWaveform

    var body: some View {
        VStack(spacing: 4) {
            ForEach(LFOWaveform.allCases) { wf in
                Button {
                    withAnimation { selection = wf }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(selection == wf ? Color.synthPurple : Color.clear)
                            .overlay(Circle().stroke(Color.synthPurple.opacity(0.5), lineWidth: 1))
                            .frame(width: 8, height: 8)

                        Text(wf.displayName)
                            .font(.synthCaption)
                            .foregroundStyle(selection == wf ? .white : .synthSecondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(
                        selection == wf ? Color.synthPurple.opacity(0.15) : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}

// MARK: - LFOPreviewView

/// Draws a single-cycle preview of the selected LFO waveform.
private struct LFOPreviewView: View {
    let waveform: LFOWaveform
    let rate: Float
    let depth: Float

    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let amp = h * 0.4
            let mid = h / 2

            var path = Path()
            let steps = 200
            for i in 0...steps {
                let t = Float(i) / Float(steps)
                let y: Float
                switch waveform {
                case .sine:     y = Float(mid) - Float(amp) * sin(t * 2 * .pi)
                case .triangle: y = Float(mid) - Float(amp) * (2 * abs(2 * t - 1) - 1)
                case .sawtooth: y = Float(mid) - Float(amp) * (2 * t - 1)
                case .square:   y = Float(mid) - Float(amp) * (t < 0.5 ? 1 : -1)
                case .random:   y = Float(mid) - Float(amp) * sin(t * 6 * .pi) * 0.7
                }
                let pt = CGPoint(x: Double(t) * Double(w), y: Double(y))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            ctx.stroke(path, with: .color(.synthPurple.opacity(0.8)), lineWidth: 1.2)
        }
        .background(Color.synthSurface)
    }
}
