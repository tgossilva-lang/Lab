function Resolve-SpecialPath {
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    if ($Path -match '^PublicDesktop:(.+)$') {
        return "C:\\Users\\Public\\Desktop\\$($Matches[1])"
    }
    if ($Path -match '^DefaultProfile:(.+)$') {
        return "C:\\Users\\Default\\$($Matches[1])"
    }
    if ($Path -match '^PublicDocuments:(.+)$') {
        return "C:\\Users\\Public\\Documents\\$($Matches[1])"
    }
    return $Path
}

function Convert-ToUncPath {
    param(
        [Parameter(Mandatory)] [string] $HostName,
        [Parameter(Mandatory)] [string] $LocalPath
    )
    $drive, $rest = $LocalPath -split ':', 2
    $trimmed = $rest.TrimStart('\\')
    return "\\\\$HostName\\$drive$\\$trimmed"
}

function Test-SafeDeletePath {
    param(
        [Parameter(Mandatory)] [string] $Path
    )
    $blocked = @('C:\\Windows', 'C:\\Program Files', 'C:\\Program Files (x86)')
    foreach ($prefix in $blocked) {
        if ($Path -like "$prefix*") { return $false }
    }
    return $true
}

function Invoke-Robocopy {
    param(
        [Parameter(Mandatory)] [string] $Source,
        [Parameter(Mandatory)] [string] $Destination,
        [int] $ThrottleIpgMs = 0,
        [string] $LogPath,
        [ValidateSet('sync','copy')] [string] $Mode = 'sync'
    )
    $args = @("\"$Source\"", "\"$Destination\"")
    if ($Mode -eq 'sync') {
        $args += '/MIR'
    } else {
        $args += '/E'
    }
    $args += @('/XO', '/FFT', '/R:2', '/W:5', '/Z', '/NP')
    if ($ThrottleIpgMs -gt 0) { $args += "/IPG:$ThrottleIpgMs" }
    if ($LogPath) { $args += "/LOG+:$LogPath" }
    $process = Start-Process -FilePath robocopy.exe -ArgumentList $args -Wait -PassThru -NoNewWindow
    return $process.ExitCode
}

function Invoke-SyncFolder {
    param(
        [Parameter(Mandatory)] [string] $HostName,
        [Parameter(Mandatory)] [string] $SourcePath,
        [Parameter(Mandatory)] [string] $DestPath,
        [int] $ThrottleIpgMs = 0,
        [string] $LogPath
    )
    $localDest = Resolve-SpecialPath -Path $DestPath
    $destUnc = Convert-ToUncPath -HostName $HostName -LocalPath $localDest
    return Invoke-Robocopy -Source $SourcePath -Destination $destUnc -ThrottleIpgMs $ThrottleIpgMs -LogPath $LogPath -Mode 'sync'
}

function Invoke-CollectPath {
    param(
        [Parameter(Mandatory)] [string] $HostName,
        [Parameter(Mandatory)] [string] $SourcePath,
        [Parameter(Mandatory)] [string] $CollectRoot,
        [int] $ThrottleIpgMs = 0,
        [string] $LogPath
    )
    $localSource = Resolve-SpecialPath -Path $SourcePath
    $sourceUnc = Convert-ToUncPath -HostName $HostName -LocalPath $localSource
    $dateFolder = (Get-Date -Format 'yyyy-MM-dd_HHmmss')
    $destRoot = Join-Path -Path $CollectRoot -ChildPath $HostName
    $dest = Join-Path -Path $destRoot -ChildPath $dateFolder
    if (-not (Test-Path -Path $dest)) {
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    return Invoke-Robocopy -Source $sourceUnc -Destination $dest -ThrottleIpgMs $ThrottleIpgMs -LogPath $LogPath -Mode 'copy'
}

Export-ModuleMember -Function Resolve-SpecialPath, Convert-ToUncPath, Test-SafeDeletePath, Invoke-SyncFolder, Invoke-CollectPath, Invoke-Robocopy
