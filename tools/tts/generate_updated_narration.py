import os
import sys
from pathlib import Path

UPDATED_LINES = [
    {
        "id": "03-today",
        "frame": 3,
        "text": "On Today, add a task and choose who it's for. Here, a grocery request stays visible with its recipient and acceptance status. Members can accept, ask for help, and mark work done, so responsibilities are clear.",
        "instruct": "Warm, clear, conversational English. Consistent natural speaking voice."
    },
    {
        "id": "04-moments",
        "frame": 4,
        "text": "Keep the good moments together. Take a photo, add a caption, and choose whether to include where it was captured. Share it privately with your space, then react with Stewardie's clay expressions.",
        "instruct": "Warm, clear, conversational English. Consistent natural speaking voice."
    },
    {
        "id": "05-location",
        "frame": 5,
        "text": "Share your location when it helps, with the space you choose. Select fifteen minutes, thirty minutes, or one hour. You can stop sharing at any time. Opening the map never starts sharing for you.",
        "instruct": "Warm, clear, conversational English. Consistent natural speaking voice."
    },
    {
        "id": "06-plans-moods",
        "frame": 6,
        "text": "Coordinate household life with shared plans and quiet emotional check-ins. Add dinner dates and deep cleans directly to your shared calendar, and share your daily mood so housemates know when you need quiet focus or when you're ready to celebrate.",
        "instruct": "Calm, empathetic, supportive, harmonious"
    },
    {
        "id": "07-outro",
        "frame": 7,
        "text": "Whether it's an apartment with roommates, a family home, or a dorm crew, Stewardie gives you a private haven built for your people. Stewardie: Your people. Your plans. Your little moments. Ready for your crew.",
        "instruct": "Uplifting, inspiring, celebratory, punchy"
    }
]

def main():
    import torch
    import soundfile as sf
    from qwen_tts import Qwen3TTSModel

    project_root = Path(__file__).resolve().parents[2]
    out_dir = project_root / "videos" / "stewardie-launch" / "assets" / "audio" / "narration"
    out_dir.mkdir(parents=True, exist_ok=True)

    target_ids = set(sys.argv[1:]) if len(sys.argv) > 1 else None

    print("Loading Qwen3-TTS model: Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice on CPU...")
    model = Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        device_map="cpu",
        dtype=torch.float32,
    )
    print("Qwen3-TTS loaded successfully!")

    speaker = "aiden"
    for item in UPDATED_LINES:
        if target_ids and item["id"] not in target_ids:
            continue
        out_file = out_dir / f"{item['id']}.wav"
        print(f"\n[Frame {item['frame']}] Synthesizing {item['id']}...")
        print(f"Text: \"{item['text']}\"")

        kwargs = {
            "text": item["text"],
            "language": "English",
            "speaker": speaker,
        }
        if "instruct" in item and item["instruct"]:
            kwargs["instruct"] = item["instruct"]

        # Never silently switch speaker/model when a segment fails.
        torch.manual_seed(42)
        wavs, sr = model.generate_custom_voice(**kwargs)

        sf.write(str(out_file), wavs[0], sr)
        print(f"Saved: {out_file} ({len(wavs[0]) / sr:.2f}s, {sr}Hz)")

    print("\nAll updated narration tracks successfully generated!")

if __name__ == "__main__":
    main()
