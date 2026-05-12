# record-demo.ps1 - Records the bottom-right corner of a 4K screen
# Requires: ffmpeg (winget install ffmpeg)
#
# Usage: .\scripts\record-demo.ps1
# Output: demo.mp4

param(
    [int]$Duration = 30,
    [string]$Output = "demo.mp4"
)

$Width = 500
$Height = 400
$offsetX = 3840 - $Width
$offsetY = 2160 - $Height

Write-Host "Capturing bottom-right ${Width}x${Height} at ${offsetX},${offsetY} for ${Duration}s"

ffmpeg -y -f gdigrab -framerate 30 -offset_x $offsetX -offset_y $offsetY -video_size "${Width}x${Height}" -i desktop -t $Duration -c:v libx264 -preset fast -crf 23 -pix_fmt yuv420p $Output
