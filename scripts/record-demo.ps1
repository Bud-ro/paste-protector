# record-demo.ps1 — Records a demo of paste-protector using ffmpeg
# Requires: ffmpeg (winget install ffmpeg), paste-protector.exe in PATH or current dir
#
# Usage: .\scripts\record-demo.ps1
# Output: demo.mp4

param(
    [int]$Duration = 15,
    [string]$Output = "demo.mp4",
    [int]$Width = 400,
    [int]$Height = 300,
    [string]$Exe = ".\zig-out\bin\paste-protector.exe"
)

Write-Host "=== Paste Protector Demo Recorder ==="
Write-Host ""

# Check ffmpeg
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg not found. Install with: winget install ffmpeg"
    exit 1
}

# Start paste-protector if not running
$pp = Get-Process paste-protector -ErrorAction SilentlyContinue
if (-not $pp) {
    if (Test-Path $Exe) {
        Write-Host "Starting paste-protector..."
        Start-Process $Exe
        Start-Sleep -Seconds 2
    } else {
        Write-Host "paste-protector.exe not found at $Exe"
        Write-Host "Build first: zig build -Doptimize=ReleaseSmall -Dtarget=x86_64-windows"
        exit 1
    }
}

# Record the bottom-right corner of the screen (where notifications appear)
$screenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
$screenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
$offsetX = $screenWidth - $Width
$offsetY = $screenHeight - $Height

Write-Host "Recording ${Width}x${Height} from bottom-right corner for ${Duration}s..."
Write-Host "Copy some text now to trigger notifications!"
Write-Host ""

ffmpeg -y -f gdigrab -framerate 30 -offset_x $offsetX -offset_y $offsetY `
    -video_size "${Width}x${Height}" -i desktop `
    -t $Duration -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p `
    $Output 2>$null

if ($LASTEXITCODE -eq 0) {
    $size = (Get-Item $Output).Length / 1KB
    Write-Host "Saved: $Output ($([math]::Round($size))KB)"
} else {
    Write-Host "Recording failed. Make sure ffmpeg supports gdigrab."
}
