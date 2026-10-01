$ffmpegDir = "C:\Users\Diel\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin"
$env:PATH = "$ffmpegDir;" + $env:PATH
npx --yes hyperframes@0.8.104 render --fps 30 --quality delivery --output stewardie_demo_corrected.mp4
