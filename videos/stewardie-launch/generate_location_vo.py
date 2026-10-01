"""Regenerate location narration with the project Qwen voice."""
from pathlib import Path
import subprocess
root = Path(__file__).resolve().parents[2]
subprocess.run([str(root / "tools/tts/.venv/Scripts/python.exe"), str(root / "tools/tts/generate_updated_narration.py"), "05-location"], cwd=root, check=True)
