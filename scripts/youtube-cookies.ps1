# Export YouTube cookies so age-restricted tracks can play.
#
#   scripts\youtube-cookies.cmd
#   powershell -ExecutionPolicy Bypass -File scripts\youtube-cookies.ps1 -Browser firefox
#
# The player passes the exported file to yt-dlp. Cookies expire after a while;
# run this script again when age-restricted tracks stop working.

[CmdletBinding()]
param(
    [ValidateSet('edge', 'chrome', 'chromium', 'brave', 'opera', 'vivaldi', 'firefox')]
    [string]$Browser = 'edge',

    # Use the browser's normal profile instead of a dedicated one. Close the
    # browser first: Chromium locks its cookie database while it runs.
    [switch]$UseExistingProfile,

    # Optional YouTube video id used to verify that age-restricted playback
    # works with the exported cookies.
    [string]$TestVideo = ''
)

$ErrorActionPreference = 'Stop'

function Find-Browser([string]$Name) {
    $candidates = switch ($Name) {
        'edge' { @(
            "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
            "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
        }
        'chrome' { @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
            "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
        }
        'chromium' { @(
            "$env:LOCALAPPDATA\Chromium\Application\chrome.exe",
            "$env:ProgramFiles\Chromium\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Chromium\Application\chrome.exe")
        }
        'brave' { @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe")
        }
        'opera' { @(
            "$env:LOCALAPPDATA\Programs\Opera\opera.exe",
            "$env:ProgramFiles\Opera\opera.exe")
        }
        'vivaldi' { @(
            "$env:LOCALAPPDATA\Vivaldi\Application\vivaldi.exe",
            "$env:ProgramFiles\Vivaldi\Application\vivaldi.exe")
        }
        default { @() }
    }
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

function Write-Step([string]$Text) {
    Write-Host ''
    Write-Host $Text -ForegroundColor Cyan
}

$cookiesDir = Join-Path $env:APPDATA 'music-player-tui'
$cookiesFile = Join-Path $cookiesDir 'cookies.txt'
New-Item -ItemType Directory -Force $cookiesDir | Out-Null

if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) {
    Write-Host 'yt-dlp was not found in PATH.' -ForegroundColor Red
    Write-Host 'Install it first:  winget install --id yt-dlp.yt-dlp -e'
    Write-Host 'Then reopen the terminal and run this script again.'
    exit 1
}

$cookieSource = $Browser
$chromium = $Browser -ne 'firefox'

if ($chromium -and -not $UseExistingProfile) {
    $browserExe = Find-Browser $Browser
    if (-not $browserExe) {
        Write-Host "$Browser was not found." -ForegroundColor Red
        Write-Host 'Pick another browser with -Browser (edge, chrome, brave, opera, vivaldi, firefox).'
        exit 1
    }

    $profileDir = Join-Path $env:LOCALAPPDATA 'music-player-tui\browser-profile'
    New-Item -ItemType Directory -Force $profileDir | Out-Null

    Write-Step "A separate $Browser window will open. It uses a dedicated profile,"
    Write-Host 'so your normal browser can stay open.'
    Write-Host ''
    Write-Host 'In that window: sign in to the Google account you use for YouTube,'
    Write-Host 'open youtube.com once, then CLOSE THE WHOLE WINDOW.'
    Write-Host ''
    Write-Host 'Press Enter to open it...'
    [void](Read-Host)

    Start-Process $browserExe -ArgumentList @(
        "--user-data-dir=`"$profileDir`"",
        '--no-first-run',
        '--no-default-browser-check',
        'https://www.youtube.com/'
    )

    while ($true) {
        Start-Sleep -Seconds 3
        $running = @(Get-CimInstance Win32_Process -Filter "Name='$([IO.Path]::GetFileName($browserExe))'" |
            Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) })
        if ($running.Count -eq 0) { break }
    }
    Start-Sleep -Seconds 3
    $cookieSource = "${Browser}:$profileDir"
}
elseif ($chromium) {
    Write-Step "Close every $Browser window now, then press Enter (its cookie database is locked while it runs)."
    [void](Read-Host)
}

Write-Step "Exporting cookies from $cookieSource ..."
$exportUrl = 'https://www.youtube.com/watch?v=BaW_jenozKc'
$output = & yt-dlp --ignore-config --cookies-from-browser $cookieSource --cookies $cookiesFile `
    --skip-download --simulate --no-warnings $exportUrl 2>&1
$text = ($output | ForEach-Object { [string]$_ }) -join "`n"

if ($text -match 'Could not copy|Failed to decrypt|could not be found|Permission denied') {
    Write-Host ''
    Write-Host 'The browser cookie database could not be read.' -ForegroundColor Red
    Write-Host 'Close every window of that browser (including its background processes)'
    Write-Host 'and run this script again, or use another browser with -Browser.'
    exit 1
}

if (-not (Test-Path $cookiesFile)) {
    Write-Host ''
    Write-Host 'No cookies file was written.' -ForegroundColor Red
    Write-Host $text
    exit 1
}

$cookieText = Get-Content $cookiesFile -Raw
$signedIn = $cookieText -match '(?m)\tLOGIN_INFO\t'
if (-not $signedIn) {
    Write-Host ''
    Write-Host 'Cookies were exported, but they do not belong to a signed-in account.' -ForegroundColor Yellow
    Write-Host 'Run the script again and make sure you are logged in to YouTube before'
    Write-Host 'closing the browser window.'
    exit 1
}

Write-Host ''
Write-Host "Cookies saved to $cookiesFile" -ForegroundColor Green

if ($TestVideo) {
    Write-Step "Checking age-restricted playback with video $TestVideo ..."
    $test = & yt-dlp --ignore-config --cookies $cookiesFile --skip-download --print '%(title)s' `
        "https://www.youtube.com/watch?v=$TestVideo" 2>&1
    $testText = ($test | ForEach-Object { [string]$_ }) -join "`n"
    if ($testText -match 'Sign in to confirm your age') {
        Write-Host 'YouTube still asks to sign in for this video.' -ForegroundColor Yellow
        Write-Host 'The account may not be allowed to watch it, or the cookies are stale.'
        exit 1
    }
    if ($testText -match '^ERROR') {
        Write-Host 'Unexpected yt-dlp error:' -ForegroundColor Red
        Write-Host $testText
        exit 1
    }
    Write-Host "OK: $($testText.Trim())" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done. Open the player and play an age-restricted YouTube track.'
Write-Host 'If it stops working later, run this script again to refresh the cookies.'
