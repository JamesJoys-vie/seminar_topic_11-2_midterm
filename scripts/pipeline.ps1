param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 8080,
    [string]$NgrokUrl = $env:NGROK_PUBLIC_URL,
    [switch]$SkipNpmInstall,
    [switch]$KeepExistingDeployment,
    [switch]$SkipNgrokVerification
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Invoke-Phase {
    param(
        [string]$Name,
        [scriptblock]$Command
    )

    Write-Step $Name
    & $Command

    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        throw "$Name failed with exit code $LASTEXITCODE."
    }
}

function Normalize-BaseUrl {
    param([string]$Url)

    if (-not $Url) {
        return $null
    }

    return $Url.Trim().TrimEnd("/")
}

function Wait-ForHealth {
    param(
        [string]$HealthUrl,
        [hashtable]$Headers = @{},
        [int]$TimeoutSeconds = 30
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null

    do {
        try {
            $response = Invoke-RestMethod -Uri $HealthUrl -Headers $Headers -TimeoutSec 5
            if ($response.status -eq "UP") {
                return $response
            }

            $lastError = "Unexpected health response from $HealthUrl"
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 750
        }
    } while ((Get-Date) -lt $deadline)

    throw "Health check failed at $HealthUrl within $TimeoutSeconds seconds. Last error: $lastError"
}

function Write-PipelineSummary {
    param(
        [string]$Path,
        [string]$LocalUrl,
        [string]$NgrokUrl,
        [bool]$NgrokVerified
    )

    $lines = @(
        "Local Automation Pipeline Summary",
        "GeneratedAt: $((Get-Date).ToString('s'))",
        "Build: passed",
        "Test: passed",
        "Deploy: passed",
        "Local Health: passed",
        "Local API: $LocalUrl",
        "Local Docs: $LocalUrl/docs"
    )

    if ($NgrokVerified) {
        $lines += @(
            "ngrok Health: passed",
            "Public API: $NgrokUrl",
            "Public Docs: $NgrokUrl/docs"
        )
    } elseif ($SkipNgrokVerification) {
        $lines += "ngrok Health: skipped"
    } else {
        $lines += "ngrok Health: not configured"
    }

    Set-Content -Path $Path -Value $lines
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RuntimeDir = Join-Path $ProjectRoot ".runtime"
$SummaryPath = Join-Path $RuntimeDir "pipeline-summary.txt"
$LocalUrl = "http://${HostName}:$Port"
$LocalHealthUrl = "$LocalUrl/actuator/health"
$NgrokUrl = Normalize-BaseUrl $NgrokUrl
$NgrokVerified = $false

Set-Location $ProjectRoot
New-Item -ItemType Directory -Force -Path $RuntimeDir | Out-Null

if (-not $KeepExistingDeployment) {
    Invoke-Phase "Stopping any existing local deployment before pipeline run" {
        & (Join-Path $ProjectRoot "scripts\stop-local.ps1") -Quiet
    }
}

Invoke-Phase "Running Build phase" {
    & (Join-Path $ProjectRoot "scripts\build.ps1")
}

Invoke-Phase "Running Test phase" {
    if ($SkipNpmInstall) {
        & (Join-Path $ProjectRoot "scripts\test.ps1") -HostName $HostName -Port $Port -SkipBuild -SkipNpmInstall
    } else {
        & (Join-Path $ProjectRoot "scripts\test.ps1") -HostName $HostName -Port $Port -SkipBuild
    }
}

Invoke-Phase "Running Deploy phase" {
    & (Join-Path $ProjectRoot "scripts\deploy-local.ps1") -HostName $HostName -Port $Port -SkipBuild
}

Invoke-Phase "Verifying local deployment health" {
    Wait-ForHealth -HealthUrl $LocalHealthUrl | Out-Null
}

if ($SkipNgrokVerification) {
    Write-Step "Skipping ngrok public tunnel verification"
} elseif ($NgrokUrl) {
    Invoke-Phase "Verifying ngrok public tunnel health" {
        $headers = @{
            "ngrok-skip-browser-warning" = "true"
        }
        Wait-ForHealth -HealthUrl "$NgrokUrl/actuator/health" -Headers $headers | Out-Null
    }
    $NgrokVerified = $true
} else {
    Write-Step "No ngrok URL configured; public tunnel verification was not run"
}

Write-PipelineSummary -Path $SummaryPath -LocalUrl $LocalUrl -NgrokUrl $NgrokUrl -NgrokVerified $NgrokVerified

Write-Host ""
Write-Host "Pipeline completed successfully."
Write-Host "Build: passed"
Write-Host "Test: passed"
Write-Host "Deploy: passed"
Write-Host "Local Health: passed"
if ($NgrokVerified) {
    Write-Host "ngrok Health: passed"
    Write-Host "Public API: $NgrokUrl"
    Write-Host "Public Docs: $NgrokUrl/docs"
} elseif ($SkipNgrokVerification) {
    Write-Host "ngrok Health: skipped"
} else {
    Write-Host "ngrok Health: not configured"
}
Write-Host "Local API: $LocalUrl"
Write-Host "Local Docs: $LocalUrl/docs"
Write-Host "Summary: $SummaryPath"
