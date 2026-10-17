# Video transcript generator

`generate_whisper_demo.py` makes the `*-full.json` transcripts in `NextWord/Video/`.
It runs **on a Mac, before building the app**. The iPhone app only reads the finished JSON:
it never downloads YouTube audio or runs Whisper.

This folder sits outside `NextWord/NextWord/` on purpose, so Xcode does not bundle the script into the app.

## Pipeline

```
YouTube URL
  → yt-dlp downloads the audio only (wav)
  → FFmpeg converts it to 16 kHz mono PCM (the format Whisper expects)
  → Whisper (base.en, word_timestamps=True) gives every word a start/end time
  → group_sentences() splits the words into sentences at . ! ? (max 45 words)
  → JSON: videoID, title, clipStart, clipEnd, model, sentences, words
```

The app decodes `videoID`, `title`, `clipStart`, `clipEnd` and `sentences`
(see `NextWord/Video/VideoTranscript.swift`) and ignores the other fields.

## Setup

```bash
brew install yt-dlp ffmpeg
python3 -m venv .venv
source .venv/bin/activate
pip install numpy openai-whisper
```

Optional faster engine: `pip install faster-whisper`, then add `--engine faster`.
The first run downloads the Whisper model (`base.en` is about 140 MB).

## Example

Run from the repository root:

```bash
python3 tools/generate_whisper_demo.py "https://www.youtube.com/watch?v=heycg7D5VZw" \
  --full-video \
  --title "Lesson 1: Welcome!" \
  --output NextWord/Video/VOAWelcome-full.json
```

Leave out `--full-video` to test a short clip first (default: 60 seconds from `--clip-start`).
`--model small.en` is more accurate than `base.en` but slower.

After generating a new file, add a matching entry (video ID + transcript file name)
in `NextWord/Video/VideoLibraryView.swift`. The app refuses a transcript whose
`videoID` does not match the video.

## Current transcripts

| File | Video ID | Title |
|---|---|---|
| VOAWelcome-full.json | heycg7D5VZw | Lesson 1: Welcome! |
| LoLHighlights-full.json | i21NAHe77UM | The Most GOATED English Caster Calls in League of Legends History |
| RedBullTalkingBull-full.json | G2YToseV8aw | Max Verstappen's END OF SEASON REVIEW! \| Talking Bull |
| ThinkingBasketballCurry-full.json | t6_vawdzRok | Why no one guards Steph Curry this way \| NBA Finals Game 4 analysis |
| MrBeastCity-full.json | v9QtM6qnG50 | I Built A City To Save Kids From Illegal Labor |

All five were made with `base.en` on the full video.

## Known limits

- `base.en` mishears names, game terms and slang. The transcripts are not hand-corrected.
- Where Whisper adds little punctuation, sentences can run up to the 45-word limit (e.g. the Curry video).
- Downloading YouTube audio is done only to prepare course demo material. Check YouTube's terms
  and each video's licence before any public release.
