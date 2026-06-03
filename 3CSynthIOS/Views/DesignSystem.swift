// DesignSystem.swift
// Shared (iOS + macOS)
//
// 3CSynth design token system: colours, typography, and view modifiers.
// Follows Apple's semantic colour conventions and HIG guidelines.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI

// MARK: - Color Tokens

public extension Color {

    // Backgrounds
    static let synthBackground      = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let synthSurface         = Color(red: 0.13, green: 0.13, blue: 0.16)
    static let synthSurfaceElevated = Color(red: 0.18, green: 0.18, blue: 0.22)

    // Borders
    static let synthDivider         = Color.white.opacity(0.08)
    static let synthBorder          = Color.white.opacity(0.12)

    // Labels
    static let synthLabel           = Color.white
    static let synthSecondaryLabel  = Color.white.opacity(0.45)

    // Accent palette — each synth section has its own hue.
    static let synthAccent          = Color(red: 0.35, green: 0.60, blue: 1.00)  // Blue
    static let synthGreen           = Color(red: 0.24, green: 0.85, blue: 0.55)
    static let synthOrange          = Color(red: 1.00, green: 0.65, blue: 0.20)
    static let synthPurple          = Color(red: 0.75, green: 0.40, blue: 1.00)
    static let synthBlue            = Color(red: 0.35, green: 0.60, blue: 1.00)
    static let synthCyan            = Color(red: 0.20, green: 0.85, blue: 0.95)
    static let synthRed             = Color(red: 1.00, green: 0.30, blue: 0.35)
}

// MARK: - ShapeStyle Tokens (for foregroundStyle)

public extension ShapeStyle where Self == Color {

    static var synthBackground: Color       { .synthBackground }
    static var synthSurface: Color          { .synthSurface }
    static var synthAccent: Color           { .synthAccent }
    static var synthGreen: Color            { .synthGreen }
    static var synthOrange: Color           { .synthOrange }
    static var synthPurple: Color           { .synthPurple }
    static var synthBlue: Color             { .synthBlue }
    static var synthCyan: Color             { .synthCyan }
    static var synthSecondaryLabel: Color   { .synthSecondaryLabel }
    static var synthDivider: Color          { .synthDivider }
}

// MARK: - Typography

public extension Font {

    /// Large instrument title (e.g. "3CSYNTH" header).
    static let synthTitle = Font.system(size: 16, weight: .semibold, design: .rounded)
        .monospacedDigit()

    /// Section header (e.g. "OSC 1", "FILTER").
    static let synthSectionTitle = Font.system(size: 10, weight: .semibold, design: .rounded)

    /// Control labels, values, small text.
    static let synthCaption = Font.system(size: 10, weight: .regular, design: .rounded)
}

// MARK: - View Modifiers

/// Standard background card style for synth sections.
struct SynthSectionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color.synthSurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.synthBorder, lineWidth: 0.5)
            )
    }
}

public extension View {
    func synthSectionStyle() -> some View {
        modifier(SynthSectionStyle())
    }
}
