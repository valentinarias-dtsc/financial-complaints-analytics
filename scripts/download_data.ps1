[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$BaseUrl = 'https://www.consumerfinance.gov/data-research/consumer-complaints/search/api/v1/'

$Products = @(
    'Credit card or prepaid card',
    'Credit card',
    'Checking or savings account',
    'Money transfer, virtual currency, or money service'
)

# CFPB date_received_max is exclusive (<).
$Periods = @(
    [pscustomobject]@{ Name = '2023_h1';         Start = '2023-01-01'; EndExclusive = '2023-07-01' },
    [pscustomobject]@{ Name = '2023_h2';         Start = '2023-07-01'; EndExclusive = '2024-01-01' },
    [pscustomobject]@{ Name = '2024_h1';         Start = '2024-01-01'; EndExclusive = '2024-07-01' },
    [pscustomobject]@{ Name = '2024_h2';         Start = '2024-07-01'; EndExclusive = '2025-01-01' },
    [pscustomobject]@{ Name = '2025_01';         Start = '2025-01-01'; EndExclusive = '2025-02-01' },
    [pscustomobject]@{ Name = '2025_h1_feb_jun'; Start = '2025-02-01'; EndExclusive = '2025-07-01' },
    [pscustomobject]@{ Name = '2025_q3';         Start = '2025-07-01'; EndExclusive = '2025-10-01' },
    [pscustomobject]@{ Name = '2025_q4';         Start = '2025-10-01'; EndExclusive = '2026-01-01' }
)

$RepoRoot = Split-Path -Parent $PSScriptRoot
$OutputDir = Join-Path $RepoRoot 'data/raw'
$ManifestPath = Join-Path $OutputDir 'extraction_manifest.csv'

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$Curl = Get-Command curl.exe -ErrorAction SilentlyContinue
if (-not $Curl) {
    throw "curl.exe was not found. Install curl or make it available in PATH."
}

function Encode-QueryValue {
    param([Parameter(Mandatory)][string]$Value)
    [System.Uri]::EscapeDataString($Value)
}

function New-CfpbCsvUrl {
    param(
        [Parameter(Mandatory)][string]$Start,
        [Parameter(Mandatory)][string]$EndExclusive
    )

    $query = [System.Collections.Generic.List[string]]::new()
    $query.Add("date_received_min=$(Encode-QueryValue $Start)")
    $query.Add("date_received_max=$(Encode-QueryValue $EndExclusive)")

    foreach ($product in $Products) {
        $query.Add("product=$(Encode-QueryValue $product)")
    }

    $query.Add('format=csv')

    "${BaseUrl}?$($query -join '&')"
}

function Invoke-CfpbDownload {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$OutFile
    )

    # curl writes the response body to OutFile and only the HTTP status to stdout.
    $httpStatus = & $Curl.Source `
        --location `
        --silent `
        --show-error `
        --connect-timeout 30 `
        --retry 3 `
        --retry-delay 2 `
        --output $OutFile `
        --write-out '%{http_code}' `
        $Uri

    $curlExitCode = $LASTEXITCODE

    if ($curlExitCode -ne 0) {
        if (Test-Path $OutFile) {
            Remove-Item $OutFile -Force
        }
        throw "curl.exe failed with exit code $curlExitCode."
    }

    switch ($httpStatus) {
        '200' { return }
        '400' {
            if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
            throw "CFPB returned HTTP 400. The selected interval may exceed the 100,000-row CSV export limit or a filter may be invalid. Split this interval further and retry."
        }
        '403' {
            if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
            throw "CFPB returned HTTP 403. Access to this request was denied by consumerfinance.gov/Akamai."
        }
        default {
            if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
            throw "CFPB returned unexpected HTTP status $httpStatus."
        }
    }
}

function ConvertTo-ValidatedCfpbCsv {
    param(
        [Parameter(Mandatory)][string]$InputFile,
        [Parameter(Mandatory)][string]$OutputFile,
        [Parameter(Mandatory)][string]$Start,
        [Parameter(Mandatory)][string]$EndExclusive,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$SeenComplaintIds
    )

    $startUtc = [DateTimeOffset]::ParseExact(
        $Start,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal
    )
    $endExclusiveUtc = [DateTimeOffset]::ParseExact(
        $EndExclusive,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal
    )

    $stats = [pscustomobject]@{
        row_count             = 0
        excluded_out_of_range = 0
    }

    Import-Csv -LiteralPath $InputFile -Encoding UTF8 |
        ForEach-Object {
            $row = $_
            $receivedAt = [DateTimeOffset]::Parse(
                [string]$row.'Date received',
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal
            )

            # Enforce the half-open interval even if the API returns the boundary day.
            if ($receivedAt -lt $startUtc -or $receivedAt -ge $endExclusiveUtc) {
                $stats.excluded_out_of_range++
                return
            }

            $complaintId = [string]$row.'Complaint ID'
            if ([string]::IsNullOrWhiteSpace($complaintId)) {
                throw "A row without Complaint ID was found in '$InputFile'."
            }

            if (-not $SeenComplaintIds.Add($complaintId)) {
                throw "Duplicate Complaint ID '$complaintId' was found while processing '$InputFile'."
            }

            $stats.row_count++
            $row
        } |
        Export-Csv -LiteralPath $OutputFile -NoTypeInformation -Encoding UTF8

    if ($stats.row_count -eq 0) {
        throw "Validation failed: '$InputFile' contains no rows inside [$Start, $EndExclusive)."
    }

    $stats
}

function Test-AndRegisterCfpbCsv {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Start,
        [Parameter(Mandatory)][string]$EndExclusive,
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.HashSet[string]]$SeenComplaintIds
    )

    $startUtc = [DateTimeOffset]::ParseExact(
        $Start,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal
    )
    $endExclusiveUtc = [DateTimeOffset]::ParseExact(
        $EndExclusive,
        'yyyy-MM-dd',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::AssumeUniversal
    )
    $rowCount = 0

    Import-Csv -LiteralPath $Path -Encoding UTF8 |
        ForEach-Object {
            $receivedAt = [DateTimeOffset]::Parse(
                [string]$_.'Date received',
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::AssumeUniversal
            )

            if ($receivedAt -lt $startUtc -or $receivedAt -ge $endExclusiveUtc) {
                throw "Existing file '$Path' contains a row outside [$Start, $EndExclusive). Run with -Force to rebuild it."
            }

            $complaintId = [string]$_.'Complaint ID'
            if ([string]::IsNullOrWhiteSpace($complaintId)) {
                throw "A row without Complaint ID was found in '$Path'."
            }

            if (-not $SeenComplaintIds.Add($complaintId)) {
                throw "Duplicate Complaint ID '$complaintId' was found while validating '$Path'."
            }

            $rowCount++
        } | Out-Null

    if ($rowCount -eq 0) {
        throw "Validation failed: '$Path' contains no data rows."
    }

    [pscustomobject]@{
        row_count             = $rowCount
        excluded_out_of_range = 0
    }
}

$manifest = [System.Collections.Generic.List[object]]::new()
$seenComplaintIds = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal
)

Write-Host 'CFPB Consumer Complaint Database extraction'
Write-Host "Output directory: $OutputDir"
Write-Host "Products: $($Products -join ' | ')"
Write-Host ''

foreach ($period in $Periods) {
    $fileName = "complaints_$($period.Name).csv"
    $outputFile = Join-Path $OutputDir $fileName
    $downloadFile = "$outputFile.download.part"
    $validatedFile = "$outputFile.validated.part"

    Write-Host "[$($period.Name)] $($period.Start) to $($period.EndExclusive) (end exclusive)"

    if ((Test-Path $outputFile) -and -not $Force) {
        Write-Host "  File already exists; skipping. Use -Force to replace it."
        $validation = Test-AndRegisterCfpbCsv `
            -Path $outputFile `
            -Start $period.Start `
            -EndExclusive $period.EndExclusive `
            -SeenComplaintIds $seenComplaintIds
        $status = 'skipped_existing'
    }
    else {
        foreach ($temporaryFile in @($downloadFile, $validatedFile)) {
            if (Test-Path $temporaryFile) {
                Remove-Item $temporaryFile -Force
            }
        }

        $exportUrl = New-CfpbCsvUrl `
            -Start $period.Start `
            -EndExclusive $period.EndExclusive

        Write-Verbose "Request URL: $exportUrl"
        Write-Host "  Downloading $fileName ..."

        Invoke-CfpbDownload `
            -Uri $exportUrl `
            -OutFile $downloadFile

        if (-not (Test-Path $downloadFile)) {
            throw "Download failed: temporary file was not created for '$($period.Name)'."
        }

        if ((Get-Item $downloadFile).Length -eq 0) {
            Remove-Item $downloadFile -Force
            throw "Download failed: '$downloadFile' is empty."
        }

        $header = Get-Content -Path $downloadFile -TotalCount 1
        if ($header -notmatch 'Date received' -or $header -notmatch 'Complaint ID') {
            Remove-Item $downloadFile -Force
            throw "Unexpected response for '$($period.Name)'. A valid CFPB CSV header was not found."
        }

        try {
            $validation = ConvertTo-ValidatedCfpbCsv `
                -InputFile $downloadFile `
                -OutputFile $validatedFile `
                -Start $period.Start `
                -EndExclusive $period.EndExclusive `
                -SeenComplaintIds $seenComplaintIds
        }
        catch {
            foreach ($temporaryFile in @($downloadFile, $validatedFile)) {
                if (Test-Path $temporaryFile) {
                    Remove-Item $temporaryFile -Force
                }
            }
            throw
        }

        Remove-Item $downloadFile -Force
        Move-Item -Path $validatedFile -Destination $outputFile -Force
        Write-Host "  Saved: $outputFile"
        Write-Host "  Rows kept: $($validation.row_count); boundary rows excluded: $($validation.excluded_out_of_range)"
        $status = 'downloaded'
    }

    $fileInfo = Get-Item $outputFile
    $hash = (Get-FileHash -Path $outputFile -Algorithm SHA256).Hash

    $manifest.Add([pscustomobject]@{
        period                      = $period.Name
        date_received_min           = $period.Start
        date_received_max_exclusive = $period.EndExclusive
        file                        = $fileName
        file_size_bytes             = $fileInfo.Length
        sha256                      = $hash
        row_count                   = $validation.row_count
        excluded_out_of_range       = $validation.excluded_out_of_range
        status                      = $status
        extracted_at_utc            = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    })

    Write-Host ''
}

$manifest | Export-Csv `
    -Path $ManifestPath `
    -NoTypeInformation `
    -Encoding UTF8

Write-Host 'Extraction completed.'
Write-Host "Manifest: $ManifestPath"
Write-Host 'Use -Force to refresh existing files.'
