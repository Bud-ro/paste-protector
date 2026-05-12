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

Add-Type -AssemblyName System.Windows.Forms
$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$offsetX = $screen.Width - $Width
$offsetY = $screen.Height - $Height

Write-Host "Screen: $($screen.Width)x$($screen.Height)"
Write-Host "Capturing: ${Width}x${Height} at offset ${offsetX},${offsetY}"
Write-Host "Recording for ${Duration}s — copy some text to see notifications!"
Write-Host ""

ffmpeg -y -f gdigrab -framerate 30 `
    -offset_x $offsetX -offset_y $offsetY `
    -video_size "${Width}x${Height}" -i desktop `
    -t $Duration -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p `
    $Output

if ($LASTEXITCODE -eq 0) {
    $size = [math]::Round((Get-Item $Output).Length / 1KB)
    Write-Host "`nSaved: $Output (${size}KB)"
}
