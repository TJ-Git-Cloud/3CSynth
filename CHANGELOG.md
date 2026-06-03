# Changelog

All notable changes to 3CSynth are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).  
Versions follow [Semantic Versioning](https://semver.org/).

---

## [1.0.1] — 2026-06-03

### Fixed

- **Filter (critical)** — `StateVariableFilter.process()` called `tick()` twice per
  sample for Band Pass, High Pass, and Notch modes, advancing the integrator state
  twice and producing completely wrong frequency response in those three modes. Fixed
  by destructuring all three outputs from a single `tick()` call and selecting the
  appropriate output via the switch. (`Shared/DSP/Filter.swift`)

- **Voice — LFO pitch modulation one buffer late** — LFO vibrato was applied to
  oscillator frequencies *after* the oscillators had already rendered for the current
  buffer, causing pitch modulation to lag one full audio block (up to ~93 ms at a
  4096-frame buffer size). Frequencies are now updated before oscillators render.
  (`Shared/DSP/Voice.swift`)

- **Voice — redundant `pitchBendFactor()` computation** — `pow(2, pitchBend/12)`
  was computed twice per render call (once per oscillator). A single cached value is
  now shared between both oscillators. (`Shared/DSP/Voice.swift`)

- **Voice — dead `scratchR` allocation** — A 4096-float right-channel scratch buffer
  (16 KB per voice, 256 KB total across 16 voices) was allocated in every `Voice`
  but never written or read. The render path uses `scratchL` exclusively for
  accumulation before applying stereo gain. The unused buffer is removed.
  (`Shared/DSP/Voice.swift`)

- **SynthEngine — dead `mixBuffer` allocation** — A `mixBuffer` field (32 floats)
  was allocated in `SynthEngine.init()` and never referenced anywhere in `render()`.
  Its size (32 floats) was also far too small for any real render slice and would
  have caused an out-of-bounds write had it ever been used. The field is removed.
  (`Shared/DSP/SynthEngine.swift`)

- **PresetManager — TOCTOU race on save/delete** — Concurrent calls to `save()` or
  `delete()` could both read a stale `userPresets` snapshot, mutate it
  independently, and then write back — silently discarding one caller's changes. A
  serial `DispatchQueue` now serialises all read-modify-write operations on
  `userPresets`. (`Shared/Presets/PresetManager.swift`)

- **WavetableBank — crash when entries list is empty** — `sample(tableIndex:phase:
  frequency:sampleRate:)` used `tableIndex % max(entries.count, 1)` to compute an
  index but then unconditionally accessed `entries[index]`, crashing with a fatal
  index-out-of-bounds if `entries` was empty. A guard now returns silence (0.0) when
  no tables are registered. (`Shared/DSP/WavetableBank.swift`)

- **HybridOscillator — duplicated detune/octave formula** — `effectiveFrequency` and
  `detuneFrequency(base:)` contained identical octave-and-cents arithmetic, requiring
  any future change to be made in two places. Both now delegate to a shared private
  `detunedScale` computed property. (`Shared/DSP/HybridOscillator.swift`)

---

## [1.0.0] — 2026-06-03

### Added

- Initial release of 3CSynth — hybrid subtractive/wavetable synthesizer for
  iOS, iPadOS, and macOS with full AUv3 Audio Unit plug-in support.
- Polyphonic `SynthEngine` with steal-oldest voice allocation (16 voices).
- `HybridOscillator` with PolyBLEP anti-aliasing (Sine / Triangle / Sawtooth /
  Square / Wavetable).
- `WavetableBank` with mip-map anti-aliasing (7 factory waveforms: Saw, Square,
  Formant, Bright Pad, PWM, Digital, Sine).
- Zero-delay-feedback `StateVariableFilter` (Low Pass / Band Pass / High Pass /
  Notch).
- Exponential ADSR envelope generator (`ADSREnvelope`).
- Audio-rate `LFO` (Sine / Triangle / Sawtooth / Square / Sample-and-Hold).
- CoreMIDI input processor (`MIDIProcessor`).
- `SynthParameters` — `@Observable` parameter store with `AUParameterTree`
  builder for AUv3 automation.
- 12 factory presets across Bass, Lead, Pad, Keys, and Pluck categories.
- JSON persistence for user presets to `~/Library/Application Support/3CSynth/`.
- SwiftUI synth UI shared between the standalone app and the AUv3 plug-in view.
- `XcodeGen` `project.yml` for reproducible, one-command project generation.
- `setup.sh` bootstrap script (installs XcodeGen via Homebrew, generates project,
  opens Xcode).
