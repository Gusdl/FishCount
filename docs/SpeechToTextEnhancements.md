# Speech-to-Text Robustness Strategies for Noisy Outdoor Use

Outdoor surveys expose the recognition pipeline to wind, splashing water, and
crowd chatter. The recommendations below focus on strengthening the
speech-to-text (STT) experience so commands continue to parse correctly even in
challenging soundscapes.

## 1. Anchor the Audio Session on Voice Capture Needs

`AppleSpeechBackend` currently promotes a `.record` session with `.duckOthers`
before starting recognition, prioritising microphone input while lowering
surrounding app volumes.【F:Fischbestand/Services/Speech/AppleSpeechBackend.swift†L24-L34】 Maintain that
profile as the default, but add explicit fallbacks:

- When the ambient noise floor spikes, temporarily enable
  `.allowBluetooth`/`.allowBluetoothA2DP` so surveyors can switch to headsets
  without reconfiguring the app.
- If recognition fails repeatedly, expose a UI toggle to relax to
  `.playAndRecord` while still routing the mic, which improves stability on some
  ruggedised field devices.

## 2. Reuse RMS Analysis for Dynamic Noise Suppression

The audio tap in `AppleSpeechBackend` provides raw microphone buffers before
they are appended to the recognition request.【F:Fischbestand/Services/Speech/AppleSpeechBackend.swift†L36-L44】 Persist a rolling
RMS average there and feed it into:

- Adaptive input gain adjustments via `AVAudioSession.setInputGain(_:)` where
  supported, lowering mic sensitivity when wind gusts clip.
- A tunable VAD threshold (e.g. hysteresis with different start/stop levels)
  so the recogniser ignores long low-frequency rumble while still catching
  consonant bursts.

## 3. Layer On-Device Noise Reduction Primitives

Before forwarding audio to `SFSpeechAudioBufferRecognitionRequest`, insert an
`AVAudioUnitEQ` or `AVAudioUnitReverb` configured for high-pass filtering around
150 Hz. This attenuates wind rumble without degrading voice fundamentals.
Combine it with Apple's built-in noise suppression by enabling
`AVAudioSessionMode.voiceChat` during capture, which activates beam-forming on
compatible hardware.

## 4. Harden the Language Model Against Confusion

`VoiceParser` erkennt Satzfragmente über Wortlisten und Größenklassen-Binning
gegen den Artenkatalog.【F:Fischbestand/Services/VoiceParser.swift†L1-L69】 Improve
its resilience by:

- Extending the species alias list with common mis-hearings (e.g. "Barsch" ↔
  "Marsch") collected from field logs.【F:Fischbestand/Utilities/SpeciesCatalog.swift†L3-L29】
- Running post-recognition spelling correction using `UITextChecker` or a
  custom phonetic mapper before applying the regex parsing, catching
  background-noise substitutions like "drei" → "frei".

## 5. Close the Feedback Loop with Fast Retries

When `SFSpeechRecognizer` reports low confidence, prompt surveyors to confirm or
repeat via haptic and visual cues on `CaptureView`.【F:Fischbestand/Views/CaptureView.swift†L37-L398】
Offering a one-tap retry keeps the interaction fluid and avoids waiting out the
full detection timeout after a noisy interruption.

By combining resilient session handling, dynamic noise suppression, and smarter
post-processing, the speech-to-text experience stays reliable even when surveys
move onto windswept docks or busy fish markets.
