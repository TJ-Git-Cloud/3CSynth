// OscillatorSection.swift
// 3CSynthIOS
//
// Oscillator 1 & 2 parameter panel.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - OscillatorSection

struct OscillatorSection: View {

    @Bindable var parameters: SynthParameters

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OscillatorPanel(
                title: "OSC 1",
                waveform: $parameters.osc1Waveform,
                detune: $parameters.osc1Detune,
                octave: $parameters.osc1Octave,
                level: $parameters.osc1Level,
                wavetableIndex: $parameters.osc1WavetableIndex,
                accentColor: .synthAccent
            )

            Divider()
                .background(Color.synthDivider)

            OscillatorPanel(
                title: "OSC 2",
                waveform: $parameters.osc2Waveform,
                detune: $parameters.osc2Detune,
                octave: $parameters.osc2Octave,
                level: $parameters.osc2Level,
                wavetableIndex: $parameters.osc2WavetableIndex,
                accentColor: Color(red: 0.6, green: 0.4, blue: 1.0)
            )
        }
        .synthSectionStyle()
    }
}

// MARK: - OscillatorPanel

private struct OscillatorPanel: View {

    let title: String
    @Binding var waveform: OscillatorWaveform
    @Binding var detune: Float
    @Binding var octave: Int
    @Binding var level: Float
    @Binding var wavetableIndex: Int
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Title
            Text(title)
                .font(.synthSectionTitle)
                .foregroundStyle(accentColor)

            // Waveform selector
            WaveformPicker(selection: $waveform, accentColor: accentColor)

            // Wavetable selector (only shown when waveform == .wavetable)
            if waveform == .wavetable {
                WavetablePicker(selection: $wavetableIndex)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Knob row
            HStack(spacing: 16) {
                KnobView(
                    label: "Level",
                    value: Binding(
                        get: { Double(level) },
                        set: { level = Float($0) }
                    ),
                    range: 0...1,
                    accentColor: accentColor
                )

                KnobView(
                    label: "Detune",
                    value: Binding(
                        get: { Double(detune) },
                        set: { detune = Float($0) }
                    ),
                    range: -100...100,
                    unitSuffix: "¢",
                    accentColor: accentColor
                )

                StepperView(
                    label: "Oct",
                    value: $octave,
                    range: -2...2,
                    accentColor: accentColor
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.15), value: waveform)
    }
}

// MARK: - WaveformPicker

private struct WaveformPicker: View {
    @Binding var selection: OscillatorWaveform
    let accentColor: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(OscillatorWaveform.allCases) { wf in
                Button {
                    withAnimation(.spring(response: 0.2)) { selection = wf }
                } label: {
                    WaveformIcon(waveform: wf, isSelected: selection == wf)
                        .foregroundStyle(selection == wf ? accentColor : .synthSecondaryLabel)
                        .frame(width: 36, height: 28)
                        .background(
                            selection == wf
                                ? accentColor.opacity(0.15)
                                : Color.synthSurface
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }
}

// MARK: - WaveformIcon

/// Draws a simple iconic representation of each waveform using SwiftUI `Path`.
private struct WaveformIcon: View {
    let waveform: OscillatorWaveform
    var isSelected: Bool = false

    var body: some View {
        Canvas { ctx, size in
            let path = iconPath(for: waveform, in: size)
            ctx.stroke(path, with: .foreground, lineWidth: isSelected ? 1.5 : 1.0)
        }
        .accessibilityLabel(waveform.displayName)
    }

    private func iconPath(for waveform: OscillatorWaveform, in size: CGSize) -> Path {
        let w = size.width, h = size.height
        let mid = h / 2, amp = h * 0.35

        var path = Path()
        switch waveform {
        case .sine:
            path.move(to: CGPoint(x: 0, y: mid))
            stride(from: 0.0, through: w, by: 0.5).forEach { x in
                let y = mid - amp * sin(x / w * 2 * .pi)
                path.addLine(to: CGPoint(x: x, y: y))
            }

        case .triangle:
            path.move(to: CGPoint(x: 0, y: mid))
            path.addLine(to: CGPoint(x: w * 0.25, y: mid - amp))
            path.addLine(to: CGPoint(x: w * 0.75, y: mid + amp))
            path.addLine(to: CGPoint(x: w, y: mid))

        case .sawtooth:
            path.move(to: CGPoint(x: 0, y: mid + amp))
            path.addLine(to: CGPoint(x: w * 0.5, y: mid - amp))
            path.addLine(to: CGPoint(x: w * 0.5, y: mid + amp))
            path.addLine(to: CGPoint(x: w, y: mid - amp))

        case .square:
            path.move(to: CGPoint(x: 0, y: mid - amp))
            path.addLine(to: CGPoint(x: w * 0.5, y: mid - amp))
            path.addLine(to: CGPoint(x: w * 0.5, y: mid + amp))
            path.addLine(to: CGPoint(x: w, y: mid + amp))

        case .wavetable:
            // Abstract wave icon
            path.move(to: CGPoint(x: 0, y: mid))
            stride(from: 0.0, through: w, by: 0.5).forEach { x in
                let t = x / w
                let y = mid - amp * (sin(t * 4 * .pi) * 0.6 + sin(t * 8 * .pi) * 0.3)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

// MARK: - WavetablePicker

private struct WavetablePicker: View {
    @Binding var selection: Int

    private let bank = WavetableBank.shared

    var body: some View {
        Picker("Wavetable", selection: $selection) {
            ForEach(0 ..< bank.count, id: \.self) { i in
                Text(bank.name(at: i)).tag(i)
            }
        }
        .pickerStyle(.menu)
        .tint(.synthAccent)
        .font(.synthCaption)
    }
}

// MARK: - StepperView

private struct StepperView: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let accentColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.synthCaption)
                .foregroundStyle(.synthSecondaryLabel)

            HStack(spacing: 6) {
                Button {
                    if value > range.lowerBound { value -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.synthCaption)
                        .frame(width: 22, height: 22)
                        .background(Color.synthSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Text("\(value > 0 ? "+" : "")\(value)")
                    .font(.synthCaption.monospacedDigit())
                    .foregroundStyle(accentColor)
                    .frame(minWidth: 20)

                Button {
                    if value < range.upperBound { value += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.synthCaption)
                        .frame(width: 22, height: 22)
                        .background(Color.synthSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
    }
}
