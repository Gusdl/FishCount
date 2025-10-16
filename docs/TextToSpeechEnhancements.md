# Text-to-Speech Enhancement Strategies for Noisy Outdoor Use

Outdoor deployments expose the app's audio feedback to wind, water, and crowd
noise. The recommendations below focus on adapting text-to-speech (TTS)
behaviour so spoken prompts remain intelligible when surveyors operate in
challenging soundscapes.

## 1. Start from a Playback-Centric Audio Session

`AppleSpeechBackend` currently configures an `.record` session with
`.duckOthers` when starting recognition so that surrounding apps lower their
volume.【F:Fischbestand/Services/Speech/AppleSpeechBackend.swift†L24-L34】 When the app
needs to speak, temporarily switching to a playback-friendly session
configuration—such as `.playAndRecord` or `.spokenAudio` with
`.defaultToSpeaker`, `.allowBluetooth`, and `.duckOthers`—ensures the prompt is
projected through the device's loudspeaker or a connected headset without
muting microphone capture. Reactivating the recording session once synthesis
finishes preserves the recognition pipeline.

## 2. Dynamically Boost Synthesizer Output

The audio tap inside `AppleSpeechBackend` already receives raw buffers before
they are forwarded to the speech recogniser.【F:Fischbestand/Services/Speech/AppleSpeechBackend.swift†L36-L44】
By extending that closure to compute RMS power levels you can derive a rolling
noise estimate and scale the `AVSpeechUtterance.volume` or
`preUtteranceDelay` on the fly. Boost volume—or pause longer—whenever outdoor
noise exceeds a defined threshold. This keeps cues audible without hard-coding a
single gain level.

## 3. Prefer High-Intelligibility Voices

For German prompts, favour enhanced voices (e.g. `de-DE` "Anna" or "Markus") and
set `AVSpeechUtterance.voice = AVSpeechSynthesisVoice(language:)` to match the
recognizer locale. Enhanced voices ship with clearer articulation and better
prosody, which listeners perceive more readily outdoors.

## 4. Offer Headset & Bone-Conduction Support

Present UI affordances encouraging surveyors to pair Bluetooth headsets or
bone-conduction devices. Combined with the `.allowBluetoothA2DP` session
option, this channels TTS directly into the user's ears, bypassing ambient
noise without blocking environmental awareness.

## 5. Layer in Non-Verbal Confirmation

Reinforce speech output with short haptic taps (`UINotificationFeedbackGenerator`)
or distinctive alert tones played through `AVAudioPlayer`. Multi-modal feedback
helps users confirm recognition results even if a phrase is masked by sudden
noise bursts.

## 6. Cache Critical Prompts On-Device

Cache the most important utterances as pre-rendered audio files so they can be
played instantly via `AVAudioPlayer`, reducing latency between recognition and
confirmation. This avoids the brief synthesis delay that can otherwise be lost
amid background sounds.

By combining smarter session management, adaptive gain, intelligible voices, and
redundant cues, the text-to-speech experience can stay reliable even when
surveys take place on windswept docks or busy fish markets.
