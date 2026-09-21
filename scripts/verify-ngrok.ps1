param(
    [string]$NgrokUrl = $env:NGROK_PUBLIC_URL,
    [string]$HealthPath = "/actuator/health",
    [int]$TimeoutSeconds = 30
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Normalize-BaseUrl {
    param([string]$Url)

    if (-not $Url) {
        return $null
    }

    return $Url.Trim().TrimEnd("/")
}

function Join-UrlPath {
    param(
        [string]$BaseUrl,
        [string]$Path
    )

    return "$BaseUrl/$($Path.TrimStart('/'))"
}

function Wait-ForNgrokHealth {
    param(
        [string]$Url,
        [int]$TimeoutSeconds
    )

    $headers = @{
        "ngrok-skip-browser-warning" = "true"
    }
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $lastError = $null

    do {
        try {
            $response = Invoke-RestMethod -Uri $Url -Headers $headers -TimeoutSec 5
            if ($response.status -eq "UP") {
                return $response
            }

            $lastError = "Unexpected health response from $Url"
        } catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds 750
        }
    } while ((Get-Date) -lt $deadline)

    throw "ngrok health check failed at $Url within $TimeoutSeconds seconds. Last error: $lastError"
}

$NgrokUrl = Normalize-BaseUrl $NgrokUrl
if (-not $NgrokUrl) {
    throw "Missing ngrok URL. Pass -NgrokUrl or set NGROK_PUBLIC_URL."
}

$HealthUrl = Join-UrlPath -BaseUrl $NgrokUrl -Path $HealthPath

Write-Step "Verifying ngrok public health endpoint"
$health = Wait-ForNgrokHealth -Url $HealthUrl -TimeoutSeconds $TimeoutSeconds

Write-Host ""
Write-Host "ngrok verification passed."
Write-Host "Public API: $NgrokUrl"
Write-Host "Public Docs: $NgrokUrl/docs"
Write-Host "Public Health: $HealthUrl"
Write-Host "Health Status: $($health.status)"
