# Shared config + junction-repair logic for the OneDrive build-redirect workaround.
#
# The repo lives inside OneDrive, which locks Flutter's churning build files. To
# avoid that, the volatile build dirs are NTFS directory junctions pointing OUT
# of OneDrive (OneDrive skips reparse points). `flutter clean` (and sometimes
# Flutter itself) deletes those junction LINKS, after which the next build
# recreates them as REAL folders back inside OneDrive — re-arming the whole
# problem. `Repair-Junctions` makes the links self-healing so a stray clean can't
# strand build output in OneDrive again.
#
# Dot-source this file from the other scripts: . "$PSScriptRoot\_common.ps1"

$ErrorActionPreference = 'Stop'

# Repo root = parent of this scripts/ folder.
$script:RepoRoot = Split-Path -Parent $PSScriptRoot

# Where the redirected build dirs actually live (outside OneDrive). Override with
# the REEFBUILD_ROOT env var if the target tree ever moves.
$script:TargetRoot = if ($env:REEFBUILD_ROOT) { $env:REEFBUILD_ROOT } `
                     else { 'C:\Android\reefbuild\ReefTracker' }

# link (relative to repo root) -> target subfolder under $TargetRoot.
# Regenerable = true means the contents are disposable (safe to delete if a
# preserve-move is blocked by a lock); false means try hard to keep them.
$script:Junctions = @(
    @{ Link = 'build';           Target = 'build';          Regenerable = $false }
    @{ Link = '.dart_tool';      Target = 'dart_tool';      Regenerable = $true  }
    @{ Link = 'android\.gradle'; Target = 'android_gradle'; Regenerable = $true  }
    @{ Link = 'android\.kotlin'; Target = 'android_kotlin'; Regenerable = $true  }
)

function New-Junction([string]$Link, [string]$Target) {
    New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null
}

# Ensures every configured link is a junction pointing at its target. Idempotent:
# safe to run before every build. Returns $true if anything had to be repaired.
function Repair-Junctions {
    $repaired = $false
    foreach ($j in $script:Junctions) {
        $link   = Join-Path $script:RepoRoot $j.Link
        $target = Join-Path $script:TargetRoot $j.Target

        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }

        $item = Get-Item $link -Force -ErrorAction SilentlyContinue

        if ($null -eq $item) {
            New-Junction $link $target
            Write-Host "  created    $($j.Link)  ->  $target" -ForegroundColor Green
            $repaired = $true
            continue
        }

        if ($item.LinkType -eq 'Junction') {
            $cur = (@($item.Target)[0]).TrimEnd('\')
            if ($cur -ieq $target.TrimEnd('\')) {
                Write-Host "  ok         $($j.Link)"
            }
            else {
                cmd /c rmdir "`"$link`"" | Out-Null   # removes the link only
                New-Junction $link $target
                Write-Host "  retargeted $($j.Link)  ->  $target" -ForegroundColor Yellow
                $repaired = $true
            }
            continue
        }

        # A REAL directory: the junction was clobbered (e.g. by `flutter clean`)
        # and a build/pub-get recreated it inside OneDrive. Its contents are the
        # freshest copy, so relocate them to the target rather than losing them.
        Write-Warning "$($j.Link) is a real folder (junction was clobbered); relocating its contents to $target"
        try {
            if (Test-Path $target) { Remove-Item $target -Recurse -Force }
            Move-Item $link $target -Force            # same volume -> fast rename
            New-Junction $link $target
            Write-Host "  healed     $($j.Link)  (contents preserved)" -ForegroundColor Green
        }
        catch {
            if ($j.Regenerable) {
                # Contents are regenerable (pub get / gradle) -> drop and relink.
                Remove-Item $link -Recurse -Force
                if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
                New-Junction $link $target
                Write-Host "  healed     $($j.Link)  (contents discarded - regenerable)" -ForegroundColor Yellow
            }
            else {
                throw "Could not relocate '$link' (a file is locked). Close editors / stop the Gradle daemon and re-run. Underlying error: $($_.Exception.Message)"
            }
        }
        $repaired = $true
    }
    return $repaired
}

# Throws if any link is not a junction pointing at the expected target.
function Assert-Junctions {
    foreach ($j in $script:Junctions) {
        $link   = Join-Path $script:RepoRoot $j.Link
        $target = (Join-Path $script:TargetRoot $j.Target).TrimEnd('\')
        $item = Get-Item $link -Force -ErrorAction SilentlyContinue
        if ($null -eq $item -or $item.LinkType -ne 'Junction' -or (@($item.Target)[0]).TrimEnd('\') -ine $target) {
            throw "$($j.Link) is not a healthy junction to $target"
        }
    }
}
