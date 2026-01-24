param(
    [Parameter(Mandatory)] [string] $JobPath,
    [string] $InventoryPath
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $scriptRoot 'lib/Logging.psm1') -Force
Import-Module (Join-Path $scriptRoot 'lib/Concurrency.psm1') -Force
Import-Module (Join-Path $scriptRoot 'lib/FileOps.psm1') -Force

function Get-JobTargets {
    param(
        [object] $Job,
        [object[]] $Inventory
    )
    if ($Job.targets.hosts) {
        return $Job.targets.hosts
    }

    if ($Job.targets.hostnames) {
        return $Job.targets.hostnames | ForEach-Object { [pscustomobject]@{ hostname = $_; lab = 'default' } }
    }

    if (-not $Inventory) { return @() }

    $targets = $Inventory
    if ($Job.targets.labs) {
        $targets = $targets | Where-Object { $Job.targets.labs -contains $_.lab }
    }
    if ($Job.targets.tags) {
        $targets = $targets | Where-Object { $_.tags -and (@($_.tags) | Where-Object { $Job.targets.tags -contains $_ }).Count -gt 0 }
    }

    switch ($Job.targets.mode) {
        'one_per_lab' {
            return $targets | Group-Object lab | ForEach-Object { $_.Group[0] }
        }
        'all' { return $targets }
        default { return $targets }
    }
}

function Invoke-WithRetry {
    param(
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [int] $MaxAttempts = 3,
        [int[]] $BackoffSeconds = @(10, 30)
    )
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return & $ScriptBlock
        } catch {
            if ($attempt -ge $MaxAttempts) { throw }
            $sleep = if ($attempt -le $BackoffSeconds.Count) { $BackoffSeconds[$attempt - 1] } else { $BackoffSeconds[-1] }
            Start-Sleep -Seconds $sleep
        }
    }
}

$job = Get-Content -Path $JobPath -Raw | ConvertFrom-Json
$inventory = $null
if ($InventoryPath -and (Test-Path -Path $InventoryPath)) {
    $inventory = Get-Content -Path $InventoryPath -Raw | ConvertFrom-Json
}

$targets = Get-JobTargets -Job $job -Inventory $inventory
if (-not $targets -or $targets.Count -eq 0) {
    Write-Host 'No targets found. Check inventory or job targets.'
    exit 1
}

$jobId = $job.job_id
if (-not $jobId) {
    $jobId = (Get-Date -Format 'yyyyMMdd-HHmmss')
}

$logDir = New-LogDirectory -JobId $jobId
$summaryPath = Join-Path $logDir 'summary.json'

$credential = Get-Credential -Message 'Enter domain admin credentials for remote operations'

$globalLimit = [int]$job.concurrency.global
$perLabLimit = [int]$job.concurrency.per_lab
$throttleIpg = [int]$job.concurrency.throttle_ipg_ms

$jobStart = Get-Date

$initScript = @"
Import-Module '$scriptRoot/lib/Logging.psm1' -Force
Import-Module '$scriptRoot/lib/FileOps.psm1' -Force
"@

$workerScript = {
    param($HostItem, $Job, $Credential, $LogDir, $ThrottleIpg)

    $hostName = $HostItem.hostname
    $hostLog = Join-Path $LogDir "$hostName.log"
    $errors = @()
    $successCount = 0
    $actionCount = $Job.actions.Count
    $status = 'Completed'
    $start = Get-Date
    $metrics = [pscustomobject]@{ bytes_copied = 0; files_copied = 0 }

    Write-Log -Path $hostLog -Message "Starting job for $hostName"

    $requiresWinRM = $Job.actions | Where-Object { $_.action -in @('DeletePath','CreateShortcut') }
    $winrmAvailable = $true
    if ($requiresWinRM) {
        try {
            Test-WSMan -ComputerName $hostName -Credential $Credential | Out-Null
        } catch {
            $winrmAvailable = $false
            $errors += 'WinRM unavailable'
            Write-Log -Path $hostLog -Level 'ERROR' -Message 'WinRM unavailable. Skipping actions requiring Invoke-Command.'
        }
    }

    function Invoke-WithRetry {
        param(
            [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
            [int] $MaxAttempts = 3,
            [int[]] $BackoffSeconds = @(10, 30)
        )
        for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
            try {
                return & $ScriptBlock
            } catch {
                if ($attempt -ge $MaxAttempts) { throw }
                $sleep = if ($attempt -le $BackoffSeconds.Count) { $BackoffSeconds[$attempt - 1] } else { $BackoffSeconds[-1] }
                Start-Sleep -Seconds $sleep
            }
        }
    }

    function Update-RobocopyMetrics {
        param([string] $LogPath, [ref] $Metrics)
        $match = Select-String -Path $LogPath -Pattern 'Bytes\s*:\s*([0-9,]+)' | Select-Object -Last 1
        if ($match) {
            $bytes = $match.Matches[0].Groups[1].Value -replace ',', ''
            $Metrics.Value.bytes_copied = [int64]$bytes
        }
        $fileMatch = Select-String -Path $LogPath -Pattern 'Files\s*:\s*([0-9,]+)' | Select-Object -Last 1
        if ($fileMatch) {
            $files = $fileMatch.Matches[0].Groups[1].Value -replace ',', ''
            $Metrics.Value.files_copied = [int64]$files
        }
    }

    foreach ($action in $Job.actions) {
        try {
            Invoke-WithRetry -ScriptBlock {
                switch ($action.action) {
                    'SyncFolder' {
                        $source = $action.source_path
                        if (-not (Test-Path -Path $source)) {
                            throw "Source not accessible: $source"
                        }
                        if ($action.strategy -and $action.strategy -eq 'hash') {
                            Write-Log -Path $hostLog -Level 'WARN' -Message 'Hash strategy not supported by robocopy; using timestamp/size.'
                        }
                        $exitCode = Invoke-SyncFolder -HostName $hostName -SourcePath $source -DestPath $action.dest_path -ThrottleIpgMs $ThrottleIpg -LogPath $hostLog
                        if ($exitCode -ge 8) {
                            throw "Robocopy failed with exit code $exitCode"
                        }
                        Update-RobocopyMetrics -LogPath $hostLog -Metrics ([ref]$metrics)
                        Write-Log -Path $hostLog -Message "SyncFolder completed with code $exitCode"
                    }
                    'DeletePath' {
                        if (-not $winrmAvailable) { throw 'WinRM required for DeletePath' }
                        $target = Resolve-SpecialPath -Path $action.target_path
                        if (-not (Test-SafeDeletePath -Path $target)) { throw "Unsafe delete path: $target" }
                        Invoke-Command -ComputerName $hostName -Credential $Credential -ScriptBlock {
                            param($Path, $Recursive, $Exclude)
                            if ($Exclude -and $Exclude.Count -gt 0) {
                                Get-ChildItem -Path $Path -Recurse -Force | Where-Object { $Exclude -notcontains $_.Name } | Remove-Item -Force -Recurse
                            } else {
                                Remove-Item -Path $Path -Force -Recurse
                            }
                        } -ArgumentList $target, $action.recursive, $action.exclude_patterns
                        Write-Log -Path $hostLog -Message "DeletePath completed for $target"
                    }
                    'CreateShortcut' {
                        if (-not $winrmAvailable) { throw 'WinRM required for CreateShortcut' }
                        $shortcutPath = Resolve-SpecialPath -Path $action.shortcut_path
                        Invoke-Command -ComputerName $hostName -Credential $Credential -ScriptBlock {
                            param($Target, $Shortcut, $Icon, $Args)
                            $shell = New-Object -ComObject WScript.Shell
                            $lnk = $shell.CreateShortcut($Shortcut)
                            $lnk.TargetPath = $Target
                            if ($Icon) { $lnk.IconLocation = $Icon }
                            if ($Args) { $lnk.Arguments = $Args }
                            $lnk.Save()
                        } -ArgumentList $action.target_path, $shortcutPath, $action.icon_path, $action.args
                        Write-Log -Path $hostLog -Message "CreateShortcut completed for $shortcutPath"
                    }
                    'CollectPath' {
                        $collectRoot = $action.collect_root
                        if (-not (Test-Path -Path $collectRoot)) {
                            throw "Collect root not accessible: $collectRoot"
                        }
                        $exitCode = Invoke-CollectPath -HostName $hostName -SourcePath $action.source_path -CollectRoot $collectRoot -ThrottleIpgMs $ThrottleIpg -LogPath $hostLog
                        if ($exitCode -ge 8) {
                            throw "Robocopy failed with exit code $exitCode"
                        }
                        Update-RobocopyMetrics -LogPath $hostLog -Metrics ([ref]$metrics)
                        Write-Log -Path $hostLog -Message "CollectPath completed with code $exitCode"
                    }
                    default {
                        Write-Log -Path $hostLog -Level 'WARN' -Message "Unknown action: $($action.action)"
                    }
                }
            } -MaxAttempts 3 -BackoffSeconds @(10, 30)

            if ($action.action -ne 'Unknown') { $successCount++ }
        } catch {
            $errors += $_.Exception.Message
            Write-Log -Path $hostLog -Level 'ERROR' -Message $_.Exception.Message
        }
    }

    if ($errors.Count -gt 0 -and $successCount -eq 0) { $status = 'Failed' }
    elseif ($errors.Count -gt 0) { $status = 'Partial' }

    $end = Get-Date
    [pscustomobject]@{
        host = $hostName
        lab = $HostItem.lab
        status = $status
        start = $start
        end = $end
        duration_seconds = [math]::Round(($end - $start).TotalSeconds, 2)
        errors = $errors
        metrics = $metrics
    }
}

$commonArgs = @($job, $credential, $logDir, $throttleIpg)
$results = Invoke-HostQueue -Hosts $targets -GlobalLimit $globalLimit -PerLabLimit $perLabLimit -ScriptBlock $workerScript -CommonArgs $commonArgs -InitializationScript $initScript

$jobEnd = Get-Date
$summary = [pscustomobject]@{
    job_id = $jobId
    started_at = $jobStart
    finished_at = $jobEnd
    duration_seconds = [math]::Round(($jobEnd - $jobStart).TotalSeconds, 2)
    totals = [pscustomobject]@{
        total_hosts = $results.Count
        completed = ($results | Where-Object { $_.status -eq 'Completed' }).Count
        partial = ($results | Where-Object { $_.status -eq 'Partial' }).Count
        failed = ($results | Where-Object { $_.status -eq 'Failed' }).Count
    }
    hosts = $results
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $summaryPath

$overallStatus = if ($summary.totals.partial -gt 0 -or $summary.totals.failed -gt 0) { 1 } else { 0 }
exit $overallStatus
