function Invoke-HostQueue {
    param(
        [Parameter(Mandatory)] [array] $Hosts,
        [Parameter(Mandatory)] [int] $GlobalLimit,
        [Parameter(Mandatory)] [int] $PerLabLimit,
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [Parameter(Mandatory)] [object[]] $CommonArgs,
        [Parameter(Mandatory)] [string] $InitializationScript
    )

    $pending = [System.Collections.Generic.List[object]]::new()
    foreach ($host in $Hosts) { $pending.Add($host) }

    $running = @()
    $labCounts = @{}
    $results = @()

    while ($pending.Count -gt 0 -or $running.Count -gt 0) {
        $started = $true
        while ($running.Count -lt $GlobalLimit -and $started) {
            $started = $false
            for ($i = 0; $i -lt $pending.Count; $i++) {
                $host = $pending[$i]
                $lab = if ($host.lab) { $host.lab } else { 'default' }
                if (-not $labCounts.ContainsKey($lab)) { $labCounts[$lab] = 0 }

                if ($labCounts[$lab] -lt $PerLabLimit) {
                    $pending.RemoveAt($i)
                    $labCounts[$lab]++
                    $args = @($host) + $CommonArgs
                    $job = Start-Job -InitializationScript ([scriptblock]::Create($InitializationScript)) -ScriptBlock $ScriptBlock -ArgumentList $args
                    $running += [pscustomobject]@{ Job = $job; Lab = $lab; Host = $host }
                    $started = $true
                    break
                }
            }
        }

        $completed = Wait-Job -Job ($running.Job) -Any -Timeout 1
        if ($null -ne $completed) {
            foreach ($item in @($running)) {
                if ($item.Job.Id -eq $completed.Id) {
                    $output = Receive-Job -Job $item.Job -ErrorAction SilentlyContinue
                    $results += $output
                    Remove-Job -Job $item.Job | Out-Null
                    $labCounts[$item.Lab]--
                    $running = $running | Where-Object { $_.Job.Id -ne $item.Job.Id }
                    break
                }
            }
        }
    }

    return $results
}

Export-ModuleMember -Function Invoke-HostQueue
