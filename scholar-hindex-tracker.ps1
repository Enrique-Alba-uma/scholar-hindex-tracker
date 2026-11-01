<#
  scholar-hindex-tracker.ps1
  ---------------------------------------------------------------------------
  Logs your Google Scholar citation count and h-index, one line per run:

      2026-11-01 09:00 | Citations: 25213 | h-index: 73

  Self-contained: edit the three values in "1. Configuration" and run it.

  WHAT YOU NEED (two values, both free to obtain)
    - Your Google Scholar author ID: open your Scholar profile and copy the
      value after "user=" in the address bar.
      Example: https://scholar.google.com/citations?user=AbCdEfGhIjKL
               -> author ID is AbCdEfGhIjKL
      (This is NOT your ORCID; Scholar has its own ID.)
    - A SerpApi key: create a free account at https://serpapi.com and copy
      the "API Key" from your dashboard. Google Scholar has no official API;
      SerpApi provides one. One run per day uses about 30 searches a month,
      which fits in SerpApi's free plan (check its current limits).

  RUN IT BY HAND
      powershell -ExecutionPolicy Bypass -File .\scholar-hindex-tracker.ps1

  RUN IT EVERY DAY (Windows Task Scheduler)
    The author runs it every day at 09:00. Open PowerShell and run, changing
    the path to where you saved the script:

      $a = New-ScheduledTaskAction -Execute "powershell.exe" `
           -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Code\scholar-hindex-tracker\scholar-hindex-tracker.ps1"'
      $t = New-ScheduledTaskTrigger -Daily -At 9:00
      $s = New-ScheduledTaskSettingsSet -StartWhenAvailable
      Register-ScheduledTask -TaskName "Scholar h-index tracker" -Action $a -Trigger $t -Settings $s

    Or with the graphical tool: Task Scheduler > Create Basic Task > Daily,
    09:00 > Start a program: powershell.exe, arguments as above. Then, in
    the task's Properties > Settings, tick "Run task as soon as possible
    after a scheduled start is missed".

    REMEMBER: the task only runs while your computer is on. If it is off
    or asleep at 09:00, that day is skipped, unless "-StartWhenAvailable"
    (the option above) is set: then it runs as soon as the computer wakes.

  Author : Enrique Alba (https://github.com/Enrique-Alba-uma)
  License: MIT (see LICENSE)
#>

# 1. Configuration --------------------------------------------------------
$ScholarId = "PUT_YOUR_SCHOLAR_AUTHOR_ID_HERE"
$ApiKey    = "PUT_YOUR_SERPAPI_KEY_HERE"     # or set the SERPAPI_KEY environment variable
$LogName   = "scholar_history.txt"           # log file, created next to this script

# 2. Checks ---------------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($ApiKey -like "PUT_YOUR_*" -and $env:SERPAPI_KEY) { $ApiKey = $env:SERPAPI_KEY }
if ($ScholarId -like "PUT_YOUR_*" -or $ApiKey -like "PUT_YOUR_*") {
    Write-Host "Edit the '1. Configuration' section of this script: set your Scholar author ID and your SerpApi key."
    exit 1
}

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$logFile   = Join-Path $scriptDir $LogName
$url       = "https://serpapi.com/search.json?engine=google_scholar_author&author_id=$ScholarId&api_key=$ApiKey"
$date      = Get-Date -Format "yyyy-MM-dd HH:mm"

# 3. Query with retries (network errors are common) -----------------------
$maxTries = 3
for ($try = 1; $try -le $maxTries; $try++) {
    try {
        $response  = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 15
        if ($response.error) { throw "SerpApi says: $($response.error)" }
        $citations = $response.cited_by.table[0].citations.all
        $hIndex    = $response.cited_by.table[1].h_index.all
        if ($null -eq $citations -or $null -eq $hIndex) {
            throw "SerpApi did not return the expected data. Check your author ID and API key."
        }
        $line = "$date | Citations: $citations | h-index: $hIndex"
        Write-Host $line
        Add-Content -Path $logFile -Value $line
        exit 0
    } catch {
        if ($try -lt $maxTries) {
            Start-Sleep -Seconds 10
        } else {
            $line = "$date | ERROR after $maxTries attempts: $($_.Exception.Message)"
            Write-Host $line
            Add-Content -Path $logFile -Value $line
            exit 2
        }
    }
}
