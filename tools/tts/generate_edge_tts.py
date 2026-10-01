import asyncio
import os
from pathlib import Path
import edge_tts

SCRIPT_LINES = [
    {
        "id": "01-chaos",
        "frame": 1,
        "text": "Living together should feel like a team, not a chore list. But between buried group chats, forgotten groceries, and passive-aggressive sticky notes, shared living easily gets messy."
    },
    {
        "id": "02-intro",
        "frame": 2,
        "text": "Meet Stewardie—the warm, tactile shared-life app that turns household chaos into joyful connection for families, housemates, and crews."
    },
    {
        "id": "03-today",
        "frame": 3,
        "text": "At the center is the Today view—a clear, stress-free checklist of who's doing what right now. When you complete a task, you get instant tactile audio and celebration, keeping everyone accountable without nagging."
    },
    {
        "id": "04-moments",
        "frame": 4,
        "text": "Shared living isn't just chores—it's shared memories. Moments gives your inner circle a private, algorithm-free space to share daily snapshots and react with custom Soft Pop clay emojis."
    },
    {
        "id": "05-moods",
        "frame": 5,
        "text": "Stay emotionally attuned with quick daily mood check-ins. Know instantly if someone needs quiet time or is ready to celebrate, preventing misunderstandings before they happen."
    },
    {
        "id": "06-spaces",
        "frame": 6,
        "text": "Whether it's an apartment with roommates, a family home, or a dorm crew, create isolated spaces with instant QR invites and private data boundaries."
    },
    {
        "id": "07-outro",
        "frame": 7,
        "text": "Stewardie: Your people. Your plans. Your little moments. Built with Flutter, ready for your crew."
    }
]

async def generate_all(voice: str = "en-US-GuyNeural"):
    project_root = Path(__file__).resolve().parents[2]
    out_dir = project_root / "videos" / "stewardie-launch" / "assets" / "audio" / "narration"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Generating studio narration using voice: {voice}")
    for item in SCRIPT_LINES:
        out_file = out_dir / f"{item['id']}.wav"
        mp3_file = out_dir / f"{item['id']}.mp3"
        print(f"Synthesizing [{item['id']}]...")
        communicate = edge_tts.Communicate(item["text"], voice, rate="-4%", pitch="+0Hz")
        await communicate.save(str(mp3_file))
        
        # Also copy or convert to .wav (standard wave header or direct rename/ffmpeg)
        # Note: browser <audio> supports both .mp3 and .wav natively!
        # If wav required, we can copy or convert
        import shutil
        shutil.copyfile(str(mp3_file), str(out_file))
        print(f"Saved: {out_file} ({out_file.stat().st_size} bytes)")

if __name__ == "__main__":
    asyncio.run(generate_all())
