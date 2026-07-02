# Recreates any clobbered build junction (build, .dart_tool, android\.gradle,
# android\.kotlin) so build output redirects out of OneDrive again. Idempotent —
# run it any time, especially after an accidental `flutter clean`.
#
#   powershell -ExecutionPolicy Bypass -File scripts\heal-junctions.ps1

. "$PSScriptRoot\_common.ps1"

Write-Host "Healing build junctions (target root: $script:TargetRoot)" -ForegroundColor Cyan
$repaired = Repair-Junctions
if ($repaired) {
    Write-Host "`nJunctions repaired. If .dart_tool was rebuilt, run 'flutter pub get'." -ForegroundColor Cyan
} else {
    Write-Host "`nAll junctions already healthy." -ForegroundColor Cyan
}
