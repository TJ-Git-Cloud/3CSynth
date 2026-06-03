# 3CSynth — Hybrid Synthesizer

A production-quality hybrid subtractive/wavetable synthesizer for iOS, iPadOS, and macOS, with a full AUv3 Audio Unit plug-in that loads in Logic Pro.

---

## Architecture Overview

```
3CSynth/
├── Shared/                      ← Platform-independent code (add to all targets)
│   ├── DSP/
│   │   ├── SynthEngine.swift    ← Polyphonic engine, voice pool, MIDI dispatch
│   │   ├── Voice.swift          ← Single voice: osc → filter → env chain
│   │   ├── HybridOscillator.swift ← PolyBLEP subtractive + wavetable oscillator
│   │   ├── WavetableBank.swift  ← Pre-computed mip-mapped wavetable library
│   │   ├── Filter.swift         ← Zero-delay-feedback state variable filter (LP/HP/BP/Notch)
│   │   ├── Envelope.swift       ← Exponential ADSR envelope
│   │   └── LFO.swift            ← Audio-rate LFO (Sine/Tri/Saw/Square/S&H)
│   ├── Parameters/
│   │   └── SynthParameters.swift ← @Observable parameter store + AUParameterTree builder
│   └── Presets/
│       ├── Preset.swift          ← Codable preset model + 12 factory presets
│       └── PresetManager.swift   ← Load/save/delete with JSON persistence
│
├── 3CSynthAU/                     ← AUv3 Extension target
│   ├── ThreeCSynthAudioUnit.swift     ← AUAudioUnit subclass, real-time render block, MIDI
│   ├── ThreeCSynthAudioUnitViewController.swift ← AUViewController hosting SwiftUI SynthView
│   └── Info.plist               ← AudioComponents registration (edit bundle IDs)
│
├── 3CSynthIOS/                    ← iOS / iPadOS app target
│   ├── ThreeCSynthApp.swift           ← @main, AVAudioEngine setup, ThreeCSynthAppModel
│   └── Views/
│       ├── ContentView.swift    ← Root layout (tab strip + keyboard)
│       ├── SynthView.swift      ← Shared synth UI (used by app + AUv3)
│       ├── KeyboardView.swift   ← Multi-touch piano keyboard (UIKit)
│       ├── OscillatorSection.swift ← Osc 1 & 2 panel
│       ├── FilterSection.swift  ← Filter + filter envelope panel
│       ├── EnvelopeSection.swift ← Amp envelope + ADSR shape preview
│       ├── ModulationSection.swift ← LFO controls
│       ├── EffectsSection.swift ← Reverb + delay
│       ├── KnobView.swift       ← Drag-to-adjust rotary knob
│       ├── PresetsView.swift    ← Preset browser sheet
│       └── DesignSystem.swift   ← Colours, typography, view modifiers
│
└── 3CSynthMac/                    ← macOS companion app target
    ├── ThreeCSynthMacApp.swift        ← @main, AVAudioEngine, ThreeCSynthMacAppModel
    └── Views/
        └── MacContentView.swift ← Three-column macOS layout + NSView keyboard
```

---

## Setting Up in Xcode — One Command

The project includes a `project.yml` for **XcodeGen**, which generates a complete, ready-to-build `3CSynth.xcodeproj` automatically. No manually creating targets or dragging files.

### Quick start

```bash
# 1. Open Terminal and navigate to this folder
cd /path/to/3CSynth

# 2. Run the setup script (installs XcodeGen via Homebrew if needed)
chmod +x setup.sh
./setup.sh
```

The script installs XcodeGen, generates `3CSynth.xcodeproj`, and opens it in Xcode.  
Select the **3CSynthIOS** scheme and press **⌘R** to build.

### Before building — two things to set in project.yml

Open `project.yml` and fill in:

```yaml
DEVELOPMENT_TEAM: "YOUR_TEAM_ID"   # your 10-char Apple Developer Team ID
```

And change the bundle ID prefix from `com.yourcompany` to your own reverse-DNS identifier. Then re-run:

```bash
xcodegen generate
```

### Register your AUv3 manufacturer code

Open `3CSynthAU/Info.plist` and replace `Prma` with your registered 4-character OSType.  
Register at [developer.apple.com](https://developer.apple.com/contact/request/appleaudiounit/).

### Load in Logic Pro

1. Build and run the **3CSynthIOS** scheme on an Apple Silicon Mac — this registers the AUv3 with the system.
2. Open **Logic Pro** → create a **Software Instrument** track.
3. Click the instrument slot → **AU Instruments › 3CSynth Audio › 3CSynth**.

---

## DSP Design Notes

### Oscillators — PolyBLEP Anti-Aliasing

Classic waveforms (sawtooth, square) use the **PolyBLEP** (Polynomial Bandlimited Step) technique to suppress aliasing without expensive oversampling. This produces alias-free output at all pitches using only a small per-sample correction term.

Reference: Välimäki & Pakarinen (2012), *"Aliasing Reduction in Clipped Signals Using a Novel Residual Signal Approach"*.

### Wavetable — Mip-Map Anti-Aliasing

The `WavetableBank` builds a mip-map pyramid for each waveform at startup. The oscillator selects the mip level whose highest harmonic falls just below Nyquist at the current pitch, preventing aliasing at high notes without needing runtime filtering.

### Filter — Zero-Delay-Feedback SVF

The `StateVariableFilter` uses the **TPT (Topology-Preserving Transform)** formulation, which eliminates the one-sample delay inherent in naive bilinear-transformed filters. This allows resonance up to self-oscillation without numerical instability.

Reference: Zavalishin (2012), *"The Art of VA Filter Design"*, chapter 4.

### Envelope — Exponential RC Approximation

Attack and release use a one-pole IIR filter with coefficient `e^(–1/(t·fs))`, matching the exponential curve of an analogue RC circuit and producing the musically familiar "60% in one time-constant" behaviour.

### Real-Time Safety

The `SynthEngine.render(outputBufferList:frameCount:)` path is designed to be **allocation-free and lock-free**:

- Voice scratch buffers are pre-allocated in `Voice.init()`.
- MIDI events are delivered synchronously in the `AURenderEvent` list before rendering begins.
- Swift `Array` subscript access (no bounds-checked overhead on the fast path) and `vDSP` vector operations are used for the mix stage.
- `@Observable` property changes from the UI are read by the render block using the shared `SynthParameters` reference without locking; the render block reads values atomically thanks to Swift's memory model for struct properties.

---

## Customisation

### Adding a custom wavetable

```swift
WavetableBank.shared.register(name: "My Wave") { phase in
    // Return a sample for normalised phase 0…1.
    sin(phase * 2 * .pi) + 0.3 * sin(phase * 6 * .pi)
}
```

Call this before audio rendering begins (e.g. in `ThreeCSynthApp.init()`).

### Adding a new parameter

1. Add a stored property to `SynthParameters`.
2. Add an `AUParameter` entry in `buildParameterTree()` with the next available address.
3. Handle the address in both `apply(address:value:)` and `valueFor(address:)`.
4. Read the parameter in `Voice.render(...)` or the relevant DSP struct.

### Voice count

Change `k3CSynthMaxVoices` in `SynthEngine.swift`. Each voice allocates ~32 KB of pre-allocated buffers, so 16 voices ≈ 512 KB at startup.

---

## Requirements

- Xcode 16+
- iOS 17+ / macOS 14+
- Logic Pro 11+ for AUv3 hosting
- Swift 5.9+
- Apple Developer account (for AUv3 registration)

---

## Factory Presets

| Name | Category |
|---|---|
| Sub Drop | Bass |
| Acid Bass | Bass |
| Classic Saw Lead | Lead |
| Pulse Lead | Lead |
| Screamer | Lead |
| Strings Pad | Pad |
| Atmosphere | Pad |
| Warm Blanket | Pad |
| Electric Piano | Keys |
| Drawbar Organ | Keys |
| Crystal Pluck | Pluck |
| Harp | Pluck |

---

## License

Copyright © 2026 3CSynth Audio. All rights reserved.
