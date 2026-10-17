"""Generate the word-timed transcript JSON bundled with NextWord's Video tab.

Run this on a Mac with yt-dlp, FFmpeg, and openai-whisper installed. The iPhone
reads the resulting JSON; it does not download YouTube audio or run Whisper.
See tools/README.md for setup and example commands.
"""

import argparse
import json
import re
import subprocess
import tempfile
import wave
from pathlib import Path
from urllib.parse import parse_qs, urlparse

import numpy as np


def video_id_from(value):
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", value):
        return value

    parsed = urlparse(value)
    host = (parsed.hostname or "").lower()
    parts = parsed.path.strip("/").split("/")
    if host in ("youtu.be", "www.youtu.be"):
        candidate = parts[0]
    elif host == "youtube.com" or host.endswith(".youtube.com"):
        if parts[0] == "watch":
            candidate = parse_qs(parsed.query).get("v", [""])[0]
        elif parts[0] in ("embed", "shorts", "live") and len(parts) > 1:
            candidate = parts[1]
        else:
            candidate = ""
    else:
        candidate = ""

    if not re.fullmatch(r"[A-Za-z0-9_-]{11}", candidate):
        raise ValueError("Provide a YouTube URL or an 11-character video ID.")
    return candidate


def group_sentences(words):
    """Keep word timings while making punctuation-based rows for the app."""
    sentences = []
    first = 0
    abbreviations = {"mr.", "mrs.", "ms.", "dr.", "prof.", "e.g.", "i.e.", "vs."}

    for index, word in enumerate(words):
        token = word["text"]
        punctuation_end = bool(re.search(r"[.!?][\"'’)]*$", token)) and token.lower() not in abbreviations
        last_word = index == len(words) - 1
        maximum_length = index - first + 1 >= 45
        if not (punctuation_end or last_word or maximum_length):
            continue

        part = words[first:index + 1]
        sentences.append({
            "text": " ".join(item["text"] for item in part),
            "start": part[0]["start"],
            "end": part[-1]["end"],
            "wordStart": first,
            "wordEnd": index + 1,
        })
        first = index + 1

    return sentences


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("video", help="YouTube URL or video ID")
    parser.add_argument("--clip-start", type=float, default=0, help="Start time in seconds")
    parser.add_argument("--clip-seconds", type=float, default=60, help="Clip length in seconds")
    parser.add_argument("--full-video", action="store_true", help="Transcribe the complete video")
    parser.add_argument("--audio-file", type=Path, help="Use an already downloaded audio clip")
    parser.add_argument("--keep-audio", type=Path, help="Save the exact 16 kHz mono WAV sent to Whisper")
    parser.add_argument("--yt-dlp", default="yt-dlp", help="Path to yt-dlp executable")
    parser.add_argument("--ffmpeg", default="ffmpeg", help="Path to FFmpeg executable")
    parser.add_argument("--model", default="base.en", help="Whisper model name")
    parser.add_argument("--engine", choices=("openai", "faster"), default="openai",
                        help="Whisper implementation (both produce the same JSON format)")
    parser.add_argument("--model-cache", type=Path, help="Optional Whisper model cache directory")
    parser.add_argument("--title", default="YouTube video", help="Title shown in the app")
    # Always name the file, e.g. NextWord/Video/MyVideo-full.json, so nothing is overwritten by accident.
    parser.add_argument("--output", type=Path, required=True, help="Where to write the transcript JSON")
    args = parser.parse_args()

    if args.clip_start < 0 or args.clip_seconds <= 0:
        parser.error("Clip start must be non-negative and clip length must be positive.")
    if args.full_video and args.clip_start != 0:
        parser.error("--full-video requires --clip-start 0.")
    video_id = video_id_from(args.video)

    with tempfile.TemporaryDirectory(prefix="youtube-whisper-") as temporary:
        if args.audio_file:
            audio = args.audio_file.resolve()
            if not audio.is_file():
                parser.error(f"Audio file does not exist: {audio}")
        else:
            audio = Path(temporary) / "clip.wav"
            command = [
                args.yt_dlp,
                "--ffmpeg-location", args.ffmpeg,
                "-f", "bestaudio",
            ]
            if not args.full_video:
                command += ["--download-sections", f"*{args.clip_start}-{args.clip_start + args.clip_seconds}"]
            command += [
                "-x", "--audio-format", "wav",
                "-o", str(Path(temporary) / "clip.%(ext)s"),
                f"https://www.youtube.com/watch?v={video_id}",
            ]
            subprocess.run(command, check=True)

        pcm = subprocess.run(
            [args.ffmpeg, "-nostdin", "-i", str(audio), "-f", "s16le", "-ac", "1", "-ar", "16000", "-"],
            check=True,
            capture_output=True,
        ).stdout
        expected_samples = round(args.clip_seconds * 16000)
        if not args.full_video and len(pcm) > expected_samples * 2:
            # yt-dlp's section download may retain audio pre-roll before the
            # requested start; the tail ends at the requested clip end.
            pcm = pcm[-expected_samples * 2:]
        if args.keep_audio:
            args.keep_audio.parent.mkdir(parents=True, exist_ok=True)
            with wave.open(str(args.keep_audio), "wb") as saved_audio:
                saved_audio.setnchannels(1)
                saved_audio.setsampwidth(2)
                saved_audio.setframerate(16000)
                saved_audio.writeframes(pcm)
            print(f"Saved processed audio to {args.keep_audio}")
        samples = np.frombuffer(pcm, np.int16).astype(np.float32) / 32768.0
        if args.engine == "faster":
            from faster_whisper import WhisperModel
            model = WhisperModel(args.model, device="cpu", compute_type="int8",
                                 download_root=str(args.model_cache) if args.model_cache else None)
            segments, _ = model.transcribe(samples, language="en", word_timestamps=True)
            recognized_words = (word for segment in segments for word in segment.words or [])
            timed_words = ((word.word, word.start, word.end) for word in recognized_words)
        else:
            import whisper
            model = whisper.load_model(
                args.model,
                download_root=str(args.model_cache) if args.model_cache else None,
            )
            result = model.transcribe(samples, language="en", word_timestamps=True, fp16=False)
            timed_words = (
                (word["word"], word["start"], word["end"])
                for segment in result["segments"]
                for word in segment.get("words", [])
            )

        words = [
            {
                "text": text.strip(),
                "start": round(args.clip_start + start, 2),
                "end": round(args.clip_start + end, 2),
            }
            for text, start, end in timed_words
            if text.strip()
        ]

    if not words:
        raise RuntimeError("Whisper found no spoken words in this clip; try another time range.")
    sentences = group_sentences(words)

    payload = {
        "videoID": video_id,
        "title": args.title,
        "clipStart": args.clip_start,
        "clipEnd": round(args.clip_start + len(samples) / 16000, 2),
        "model": args.model,
        "sentences": sentences,
        "words": words,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(sentences)} sentences and {len(words)} timed words to {args.output}")


if __name__ == "__main__":
    main()
