function New-LogDirectory {
    param(
        [Parameter(Mandatory)] [string] $JobId,
        [string] $BasePath = (Join-Path -Path (Get-Location) -ChildPath 'logs')
    )
    $jobPath = Join-Path -Path $BasePath -ChildPath $JobId
    if (-not (Test-Path -Path $jobPath)) {
        New-Item -ItemType Directory -Path $jobPath -Force | Out-Null
    }
    return $jobPath
}

function Write-Log {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Message,
        [ValidateSet('INFO','WARN','ERROR')] [string] $Level = 'INFO'
    )
    $timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $line = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Path -Value $line
}

Export-ModuleMember -Function New-LogDirectory, Write-Log
