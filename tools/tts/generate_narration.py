import os
import sys
import argparse
from pathlib import Path

# Script lines mapping to storyboard frames
SCRIPT_LINES = [
    {
        "id": "01-chaos",
        "frame": 1,
        "text": "Living together should feel like a team, not a chore list. But between buried group chats, forgotten groceries, and passive-aggressive sticky notes, shared living easily gets messy.",
        "instruct": "Empathetic, warm, conversational, relatable"
    },
    {
        "id": "02-intro",
        "frame": 2,
        "text": "Meet Stewardie—the warm, tactile shared-life app that turns household chaos into joyful connection for families, housemates, and crews.",
        "instruct": "Warm, enthusiastic, welcoming, cheerful"
    },
    {
        "id": "03-today",
        "frame": 3,
        "text": "At the center is the Today view—a clear, stress-free checklist of who's doing what right now. When you complete a task, you get instant tactile audio and celebration, keeping everyone accountable without nagging.",
        "instruct": "Confident, clear, helpful, positive"
    },
    {
        "id": "04-moments",
        "frame": 4,
        "text": "Shared living isn't just chores—it's shared memories. Moments gives your inner circle a private, algorithm-free space to share daily snapshots and react with custom Soft Pop clay emojis.",
        "instruct": "Gentle, affectionate, pleasant, warm"
    },
    {
        "id": "05-moods",
        "frame": 5,
        "text": "Stay emotionally attuned with quick daily mood check-ins. Know instantly if someone needs quiet time or is ready to celebrate, preventing misunderstandings before they happen.",
        "instruct": "Thoughtful, caring, empathetic, supportive"
    },
    {
        "id": "06-spaces",
        "frame": 6,
        "text": "Whether it's an apartment with roommates, a family home, or a dorm crew, create isolated spaces with instant QR invites and private data boundaries.",
        "instruct": "Dynamic, clear, modern, practical"
    },
    {
        "id": "07-outro",
        "frame": 7,
        "text": "Stewardie: Your people. Your plans. Your little moments. Built with Flutter, ready for your crew.",
        "instruct": "Uplifting, inspiring, celebratory, punchy"
    }
]

def generate_with_qwen(output_dir: Path, model_name: str = "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"):
    print(f"Loading Qwen3-TTS model: {model_name} on CPU...")
    import torch
    import soundfile as sf
    from qwen_tts import Qwen3TTSModel

    model = Qwen3TTSModel.from_pretrained(
        model_name,
        device_map="cpu",
        dtype=torch.float32,
    )
    print("Qwen3-TTS Model loaded successfully!")

    # Check speakers
    speakers = model.get_supported_speakers() if hasattr(model, "get_supported_speakers") else []
    print(f"Supported speakers: {speakers}")
    speaker = "Vivian" if "Vivian" in speakers else (speakers[0] if speakers else None)

    for item in SCRIPT_LINES:
        out_file = output_dir / f"{item['id']}.wav"
        print(f"\n[Frame {item['frame']}] Synthesizing: {item['id']}...")
        print(f"Text: \"{item['text']}\"")
        kwargs = {
            "text": item["text"],
            "language": "English",
        }
        if speaker:
            kwargs["speaker"] = speaker
        if "instruct" in item and item["instruct"]:
            kwargs["instruct"] = item["instruct"]

        try:
            wavs, sr = model.generate_custom_voice(**kwargs)
        except Exception as e:
            print(f"Custom voice error: {e}, falling back to basic generate...")
            wavs, sr = model.generate(item["text"], language="English")

        sf.write(str(out_file), wavs[0], sr)
        print(f"Saved: {out_file} (Sample rate: {sr}Hz)")

def main():
    parser = argparse.ArgumentParser(description="Generate AI narration for Stewardie demo video")
    parser.add_argument("--output-dir", default=None, help="Directory to save narration WAV files")
    parser.add_argument("--model", default="Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice", help="Hugging Face model ID")
    parser.add_argument("--verify", action="store_true", help="Verify existing audio files")
    args = parser.parse_args()

    project_root = Path(__file__).resolve().parents[2]
    out_dir = Path(args.output_dir) if args.output_dir else project_root / "videos" / "stewardie-launch" / "assets" / "audio" / "narration"
    out_dir.mkdir(parents=True, exist_ok=True)

    if args.verify:
        all_ok = True
        for item in SCRIPT_LINES:
            target = out_dir / f"{item['id']}.wav"
            if target.exists() and target.stat().st_size > 1000:
                print(f"OK: {target.name} ({target.stat().st_size} bytes)")
            else:
                print(f"MISSING/EMPTY: {target.name}")
                all_ok = False
        sys.exit(0 if all_ok else 1)

    generate_with_qwen(out_dir, args.model)
    print("\nAll narration tracks successfully generated!")

if __name__ == "__main__":
    main()
