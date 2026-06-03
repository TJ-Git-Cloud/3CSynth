// KnobView.swift
// 3CSynthIOS
//
// A rotary knob control styled after Logic Pro's knobs.
// Supports linear and logarithmic value scaling.
// Drag vertically to adjust; double-tap to reset to default.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - KnobScaling

enum KnobScaling {
    case linear
    case logarithmic
}

// MARK: - KnobView

/// A rotary knob control.
///
/// - Drag upward to increase value, downward to decrease.
/// - Modifier+drag (Shift on hardware keyboard) for fine control.
/// - Double-tap to reset to `defaultValue`.
struct KnobView: View {

    let label: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var defaultValue: Double? = nil
    var unitSuffix: String = ""
    var scaling: KnobScaling = .linear
    var accentColor: Color = .synthAccent

    // MARK: State

    @State private var dragStartValue: Double = 0
    @State private var isDragging = false

    // MARK: Constants

    private let knobSize: CGFloat = 44
    private let startAngle: Double = -225   // degrees from 12 o'clock
    private let endAngle: Double   = 45

    // MARK: Body

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Track ring
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .stroke(
                        Color.white.opacity(0.1),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))

                // Value arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + 0.75 * normalised)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .rotationEffect(.degrees(180))
                    .shadow(color: accentColor.opacity(0.4), radius: 4)

                // Knob body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.28), Color(white: 0.14)],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: knobSize * 0.7
                        )
                    )
                    .padding(5)

                // Indicator dot
                Circle()
                    .fill(accentColor)
                    .frame(width: 4, height: 4)
                    .offset(y: -(knobSize / 2 - 9))
                    .rotationEffect(.degrees(indicatorAngle))

                // Active highlight
                if isDragging {
                    Circle()
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                        .padding(3)
                }
            }
            .frame(width: knobSize, height: knobSize)
            .contentShape(Circle())
            .gesture(dragGesture)
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
                    value = defaultValue ?? (range.lowerBound + (range.upperBound - range.lowerBound) * 0.5)
                }
            }

            // Label
            Text(label)
                .font(.synthCaption)
                .foregroundStyle(.synthSecondaryLabel)
                .lineLimit(1)

            // Value readout
            Text(formattedValue)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(isDragging ? accentColor : .synthSecondaryLabel.opacity(0.7))
                .lineLimit(1)
        }
    }

    // MARK: Computed

    private var normalised: Double {
        switch scaling {
        case .linear:
            return (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        case .logarithmic:
            let logMin = log10(max(range.lowerBound, 0.0001))
            let logMax = log10(range.upperBound)
            return (log10(max(value, 0.0001)) - logMin) / (logMax - logMin)
        }
    }

    private var indicatorAngle: Double {
        startAngle + (endAngle - startAngle) * normalised
    }

    private var formattedValue: String {
        let v = abs(value)
        if v >= 10_000 {
            return String(format: "%.0fk\(unitSuffix)", value / 1000)
        } else if v >= 1_000 {
            return String(format: "%.1fk\(unitSuffix)", value / 1000)
        } else if v >= 10 {
            return String(format: "%.1f\(unitSuffix)", value)
        } else {
            return String(format: "%.2f\(unitSuffix)", value)
        }
    }

    // MARK: Drag Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !isDragging {
                    dragStartValue = value
                    isDragging = true
                }
                let sensitivity: Double = 200
                let delta = -gesture.translation.height / sensitivity
                let mapped = mappedDelta(delta)
                value = (dragStartValue + mapped).clamped(to: range)
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    private func mappedDelta(_ normDelta: Double) -> Double {
        switch scaling {
        case .linear:
            return normDelta * (range.upperBound - range.lowerBound)
        case .logarithmic:
            let logMin = log10(max(range.lowerBound, 0.0001))
            let logMax = log10(range.upperBound)
            let currentLog = log10(max(dragStartValue, 0.0001))
            let newLog = (currentLog + normDelta * (logMax - logMin)).clamped(to: logMin...logMax)
            return pow(10, newLog) - dragStartValue
        }
    }
}

// MARK: - Double Clamped

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
