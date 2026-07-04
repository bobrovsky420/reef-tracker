# One-shot, self-healing release build. Heals the junctions BEFORE building, so
# output always redirects out of OneDrive even if a `flutter clean` clobbered a
# link. Use this instead of calling `flutter build appbundle --release` directly.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build-release.ps1

. "$PSScriptRoot\_common.ps1"

Push-Location $script:RepoRoot
try {
    Write-Host "== Release build ==" -ForegroundColor Cyan

    # 1. Release any Gradle handles from a previous run.
    & (Join-Path $script:RepoRoot 'android\gradlew.bat') --stop 2>&1 | Out-Null

    # 2. Heal + verify the junctions so the build writes outside OneDrive.
    Write-Host "`n-- Junctions --" -ForegroundColor Cyan
    Repair-Junctions | Out-Null
    Assert-Junctions
    Write-Host "  all junctions healthy" -ForegroundColor Green

    # 3. Build.
    Write-Host "`n-- flutter pub get --" -ForegroundColor Cyan
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

    # Obfuscated build (TODO T12); the split-debug-info symbols are the ONLY
    # way to symbolicate crash stacks from this build — archive them per
    # release below, never discard them.
    Write-Host "`n-- flutter build appbundle --release (obfuscated) --" -ForegroundColor Cyan
    flutter build appbundle --release --obfuscate --split-debug-info=build\symbols
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed" }

    # 4. Report the artifact at its real (out-of-OneDrive) location.
    $aab = Join-Path $script:TargetRoot 'build\app\outputs\bundle\release\app-release.aab'
    if (-not (Test-Path $aab)) { throw "Build reported success but no AAB at $aab" }
    $f = Get-Item $aab
    Write-Host "`n== Built ==" -ForegroundColor Green
    Write-Host ("  {0}" -f $f.FullName)
    Write-Host ("  {0} MB   {1}" -f [math]::Round($f.Length/1MB,1), $f.LastWriteTime)

    # 4b. Archive the obfuscation symbols per release version, outside build\
    # (which flutter clean wipes). Upload the zip alongside the AAB, or attach
    # it to the Play release for deobfuscated crash reports.
    $version = (Select-String -Path (Join-Path $script:RepoRoot 'pubspec.yaml') -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value
    $symbolsSrc = Join-Path $script:TargetRoot 'build\symbols'
    if (-not (Test-Path $symbolsSrc)) { throw "Obfuscated build produced no symbols at $symbolsSrc" }
    $symbolsDir = Join-Path $script:RepoRoot 'symbols'
    New-Item -ItemType Directory -Force $symbolsDir | Out-Null
    $symbolsZip = Join-Path $symbolsDir ("symbols-{0}.zip" -f ($version -replace '\+', '-'))
    Compress-Archive -Path (Join-Path $symbolsSrc '*') -DestinationPath $symbolsZip -Force
    Write-Host ("  symbols: {0}" -f $symbolsZip)

    # 5. Best-effort signing check (should be CN=Alexandr Bobrovsky, not debug).
    $jarsigner = Get-Command jarsigner -ErrorAction SilentlyContinue
    if ($jarsigner) {
        $sig = & $jarsigner.Source -verify -verbose -certs $aab 2>&1 | Select-String 'CN=' | Select-Object -First 1
        if ($sig) { Write-Host ("  signer: {0}" -f $sig.ToString().Trim()) }
    }
}
finally {
    Pop-Location
}
