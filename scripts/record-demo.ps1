# record-demo.ps1 — Records the bottom-right 400x300 of the screen
# Requires: ffmpeg (winget install ffmpeg)
#
# Usage: .\scripts\record-demo.ps1
# Output: demo.mp4

param(
    [int]$Duration = 15,
    [string]$Output = "demo.mp4",
    [int]$Width = 400,
    [int]$Height = 300
)

Write-Host "Recording bottom-right ${Width}x${Height} for ${Duration}s..."
Write-Host "Copy some text now to trigger notifications!"
Write-Host ""

ffmpeg -y -f gdigrab -framerate 30 -video_size "${Width}x${Height}" `
    -offset_x -$Width -offset_y -$Height -i desktop `
    -t $Duration -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p `
    $Output 2>$null

if ($LASTEXITCODE -eq 0) {
    $size = [math]::Round((Get-Item $Output).Length / 1KB)
    Write-Host "Saved: $Output (${size}KB)"
} else {
    Write-Host "Failed. Trying without offset..."
    ffmpeg -y -f gdigrab -framerate 30 -video_size "${Width}x${Height}" `
        -i desktop -t $Duration -c:v libx264 -preset fast -crf 23 `
        -pix_fmt yuv420p $Output 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Saved: $Output (top-left fallback)"
    } else {
        Write-Host "ffmpeg gdigrab failed. Install ffmpeg: winget install ffmpeg"
    }
}
