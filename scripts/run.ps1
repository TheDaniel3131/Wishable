#!/usr/bin/env pwsh
# Wishable run/build helper (Windows PowerShell).
#
# Reads KEY=VALUE pairs from .env (ignoring blanks and # comments) and forwards
# each non-empty value to Flutter as a --dart-define, then runs the given
# Flutter command. This bridges a runtime-style .env to Flutter's compile-time
# String.fromEnvironment.
#
# Usage:
#   ./scripts/run.ps1                         # defaults to: run -d chrome
#   ./scripts/run.ps1 run -d windows
#   ./scripts/run.ps1 build web
#   ./scripts/run.ps1 build apk --release
#
# Any arguments you pass replace the default Flutter subcommand/flags; the
# --dart-define values from .env are always appended.

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'

$defines = @()
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
        $eq = $trimmed.IndexOf('=')
        if ($eq -lt 1) { continue }
        $key = $trimmed.Substring(0, $eq).Trim()
        $value = $trimmed.Substring($eq + 1).Trim()
        if ($value -ne '') {
            $defines += "--dart-define=$key=$value"
        }
    }
} else {
    Write-Host "No .env found (copy .env.example to .env). Running with defaults." -ForegroundColor Yellow
}

if (-not $FlutterArgs -or $FlutterArgs.Count -eq 0) {
    $FlutterArgs = @('run', '-d', 'chrome')
}

$all = @('flutter') + $FlutterArgs + $defines
Write-Host "> $($all -join ' ')" -ForegroundColor Cyan
& flutter @FlutterArgs @defines
