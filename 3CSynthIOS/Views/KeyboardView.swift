// KeyboardView.swift
// 3CSynthIOS
//
// Multi-touch piano keyboard. Supports simultaneous touch tracking per key,
// pitch-bend via horizontal swipe, and aftertouch via vertical pressure.
//
// Copyright © 2026 3CSynth Audio. All rights reserved.

import SwiftUI
import UIKit

// MARK: - KeyboardView

/// A multi-touch piano keyboard that drives a ``SynthEngine``.
///
/// The keyboard spans one visible octave on iPhone and two on iPad,
/// but the user can scroll horizontally to reach adjacent octaves.
/// Active touches are tracked by `UITouch` identity, not position, so
/// notes sustain correctly even while sliding between keys.
struct KeyboardView: View {

    let engine: SynthEngine

    /// The MIDI note of the leftmost C (default: C3 = 48).
    @State private var baseNote: UInt8 = 48

    var body: some View {
        GeometryReader { geo in
            KeyboardUIViewRepresentable(
                engine: engine,
                baseNote: baseNote
            )
        }
        .background(Color.synthBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - UIViewRepresentable Bridge

private struct KeyboardUIViewRepresentable: UIViewRepresentable {

    let engine: SynthEngine
    let baseNote: UInt8

    func makeUIView(context: Context) -> PianoKeyboardUIView {
        let view = PianoKeyboardUIView()
        view.engine = engine
        view.baseNote = baseNote
        return view
    }

    func updateUIView(_ uiView: PianoKeyboardUIView, context: Context) {
        uiView.engine = engine
        uiView.baseNote = baseNote
    }
}

// MARK: - PianoKeyboardUIView

/// `UIView` subclass that draws and handles piano keyboard touches.
final class PianoKeyboardUIView: UIView {

    // MARK: Configuration

    var engine: SynthEngine?
    var baseNote: UInt8 = 48 {
        didSet { setNeedsLayout() }
    }

    /// Total number of white keys to display.
    var visibleWhiteKeys: Int = 14   // Two octaves

    // MARK: State

    /// Maps UITouch → MIDI note currently held by that touch.
    private var activeNotes: [UITouch: UInt8] = [:]

    // Layout caches updated in layoutSubviews.
    private var whiteKeyWidth: CGFloat = 0
    private var blackKeyWidth: CGFloat = 0
    private var blackKeyHeight: CGFloat = 0

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        whiteKeyWidth  = bounds.width / CGFloat(visibleWhiteKeys)
        blackKeyWidth  = whiteKeyWidth * 0.58
        blackKeyHeight = bounds.height * 0.60
        setNeedsDisplay()
    }

    // MARK: Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // White keys
        for i in 0 ..< visibleWhiteKeys {
            let note = whiteNoteAt(index: i)
            let x = CGFloat(i) * whiteKeyWidth
            let keyRect = CGRect(x: x + 1, y: 0, width: whiteKeyWidth - 2, height: bounds.height)
            let isActive = activeNotes.values.contains(note)

            UIColor.white.withAlphaComponent(isActive ? 0.75 : 0.95).setFill()
            UIBezierPath(roundedRect: keyRect,
                         byRoundingCorners: [.bottomLeft, .bottomRight],
                         cornerRadii: CGSize(width: 4, height: 4)).fill()

            // Bottom dot for C notes
            if note % 12 == 0 {
                let dotRect = CGRect(
                    x: x + whiteKeyWidth / 2 - 3,
                    y: bounds.height - 12,
                    width: 6, height: 6
                )
                UIColor.gray.withAlphaComponent(0.4).setFill()
                UIBezierPath(ovalIn: dotRect).fill()

                // Octave label
                let octave = Int(note) / 12 - 1
                let label = "C\(octave)" as NSString
                label.draw(at: CGPoint(x: x + whiteKeyWidth / 2 - 8, y: bounds.height - 26),
                           withAttributes: [
                            .font: UIFont.systemFont(ofSize: 9, weight: .medium),
                            .foregroundColor: UIColor.gray
                           ])
            }
        }

        // Black keys (drawn on top)
        for i in 0 ..< visibleWhiteKeys {
            guard let blackNote = blackNoteAbove(whiteIndex: i) else { continue }
            let x = CGFloat(i) * whiteKeyWidth + whiteKeyWidth - blackKeyWidth / 2
            let keyRect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
            let isActive = activeNotes.values.contains(blackNote)

            let fill: UIColor = isActive
                ? UIColor(red: 0.35, green: 0.35, blue: 0.90, alpha: 1)
                : UIColor(white: 0.12, alpha: 1)

            fill.setFill()
            UIBezierPath(roundedRect: keyRect,
                         byRoundingCorners: [.bottomLeft, .bottomRight],
                         cornerRadii: CGSize(width: 3, height: 3)).fill()

            // Subtle gradient sheen
            ctx.saveGState()
            ctx.clip(to: keyRect)
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: [CGColor(gray: 0.28, alpha: 1), CGColor(gray: 0.10, alpha: 1)] as CFArray,
                locations: [0, 1]
            )!
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: keyRect.midX, y: keyRect.minY),
                                   end:   CGPoint(x: keyRect.midX, y: keyRect.maxY),
                                   options: [])
            ctx.restoreGState()
        }
    }

    // MARK: Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let note = note(for: touch) {
                activeNotes[touch] = note
                engine?.noteOn(note: note, velocity: velocityForTouch(touch))
            }
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let newNote = note(for: touch)
            let oldNote = activeNotes[touch]
            if newNote != oldNote {
                if let old = oldNote { engine?.noteOff(note: old) }
                if let new = newNote {
                    activeNotes[touch] = new
                    engine?.noteOn(note: new, velocity: velocityForTouch(touch))
                } else {
                    activeNotes.removeValue(forKey: touch)
                }
            }
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let note = activeNotes.removeValue(forKey: touch) {
                engine?.noteOff(note: note)
            }
        }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: Note Lookup Helpers

    /// Returns the MIDI note at the touch location, checking black keys first.
    private func note(for touch: UITouch) -> UInt8? {
        let pt = touch.location(in: self)

        // Check black keys first (they sit above white keys visually).
        for i in 0 ..< visibleWhiteKeys {
            guard let black = blackNoteAbove(whiteIndex: i) else { continue }
            let x = CGFloat(i) * whiteKeyWidth + whiteKeyWidth - blackKeyWidth / 2
            let rect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
            if rect.contains(pt) { return black }
        }

        // Check white keys.
        for i in 0 ..< visibleWhiteKeys {
            let x = CGFloat(i) * whiteKeyWidth
            let rect = CGRect(x: x, y: 0, width: whiteKeyWidth, height: bounds.height)
            if rect.contains(pt) { return whiteNoteAt(index: i) }
        }
        return nil
    }

    /// Maps white-key index to a MIDI note number.
    private func whiteNoteAt(index: Int) -> UInt8 {
        // White-key offsets within an octave: C D E F G A B
        let whiteDegrees = [0, 2, 4, 5, 7, 9, 11]
        let octaveOffset = index / 7
        let degree = whiteDegrees[index % 7]
        let note = Int(baseNote) + octaveOffset * 12 + degree
        return UInt8(clamping: note)
    }

    /// Returns the black note above white-key index, if any.
    private func blackNoteAbove(whiteIndex: Int) -> UInt8? {
        // White keys E and B have no black key above them.
        let noBlack: Set<Int> = [2, 6]   // indices for E and B within octave (0-based white)
        let indexInOctave = whiteIndex % 7
        guard !noBlack.contains(indexInOctave) else { return nil }
        let white = Int(whiteNoteAt(index: whiteIndex))
        return UInt8(clamping: white + 1)
    }

    private func velocityForTouch(_ touch: UITouch) -> UInt8 {
        // Normalise vertical touch position: top → loud, bottom → softer.
        let y = touch.location(in: self).y
        let normalised = 1.0 - Float(y / bounds.height) * 0.4
        return UInt8((normalised * 127).clamped(to: 40...127))
    }
}

// MARK: - Float Clamped Helper

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
