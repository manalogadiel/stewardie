$ffmpegDir = "C:\Users\Diel\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-9.0.2-full_build\bin"
$env:PATH = "$ffmpegDir;" + $env:PATH
npx --yes hyperframes@0.8.100 render --output stewardie_demo_final.mp4
