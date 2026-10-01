import os
import sys
from pathlib import Path

UPDATED_LINES = [
    {
        "id": "03-today",
        "frame": 3,
        "text": "At the center is the Today view—a clear, stress-free checklist of who's doing what right now. When Jamie adds a task, Alex gets an instant live update and claims it with a single tap. Zero nagging, instant accountability, and celebration built right in.",
        "instruct": "Confident, engaging, lively, positive"
    },
    {
        "id": "04-moments",
        "frame": 4,
        "text": "Shared living isn't just chores—it's shared memories. Moments gives your inner circle a private, algorithm-free space to share daily snapshots inside our retro Clay TV, and react with custom Soft Pop clay emojis.",
        "instruct": "Warm, gentle, affectionate, playful"
    },
    {
        "id": "05-location",
        "frame": 5,
        "text": "Wondering when everyone will be back for dinner? Stewardie includes private, temporary location sharing. See estimated arrival times and battery levels during active 15-minute windows—keeping everyone in the loop without invasive 24/7 tracking.",
        "instruct": "Reassuring, thoughtful, clear, friendly"
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

    print("Loading Qwen3-TTS model: Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice on CPU...")
    model = Qwen3TTSModel.from_pretrained(
        "Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice",
        device_map="cpu",
        dtype=torch.float32,
    )
    print("Qwen3-TTS loaded successfully!")

    speaker = "aiden"
    for item in UPDATED_LINES:
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

        try:
            wavs, sr = model.generate_custom_voice(**kwargs)
        except Exception as e:
            print(f"Custom voice error: {e}, falling back to basic generate...")
            wavs, sr = model.generate(item["text"], language="English")

        sf.write(str(out_file), wavs[0], sr)
        print(f"Saved: {out_file} ({len(wavs[0]) / sr:.2f}s, {sr}Hz)")

    print("\nAll updated narration tracks successfully generated!")

if __name__ == "__main__":
    main()
