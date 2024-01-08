param($Context)

# $Context.Input.FromTime
# $Context.Input.UntilTime

Import-Module Az.ResourceGraph -ErrorAction Stop


$StopQuery = "resources 
| where ['type'] == 'microsoft.compute/virtualmachines' and tags['narcovm:stop:time'] != ''
| extend  narcosisseq = case(isnull(toint(tags['narcovm:stop:sequence'])), 1000000, toint(tags['narcovm:stop:sequence']))
| order by narcosisseq"
$StartQuery = "resources 
| where ['type'] == 'microsoft.compute/virtualmachines' and tags['narcovm:start:time'] != ''
| extend  narcosisseq = case(isnull(toint(tags['narcovm:start:sequence'])), 1000000, toint(tags['narcovm:start:sequence']))
| order by narcosisseq"

$BatchSize = 950





function ExecuteGraphQuery {
    param(
        [Parameter(Mandatory=$true, HelpMessage="Resource Graph Query to execute")]
        [string]$Query,

        [Parameter(Mandatory=$false, HelpMessage="Batch size")]
        [int]$BatchSize = 950,

        [Parameter(Mandatory=$true, HelpMessage="Action to apply on VMs")]
        [ValidateSet("start","stop")]
        [string]$Action,

        [Parameter(Mandatory=$true, HelpMessage="Begin of time span for evaluation")]
        [datetime]$FromTime,

        [Parameter(Mandatory=$true, HelpMessage="End  of time span for evaluation")]
        [datetime]$UntilTime
    )


    $baseData = [PSCustomObject]@{
        "Time" = [PSCustomObject]@{
            "FromTime"       = $FromTime
            "UntilTime"      = $UntilTime
        }
        "Action" = $Action
        "Resources" = @(
        )
    }

    $tasks = @()
    $previousSeq = $null
    $graphResult = $null
    while($true) {
        if($graphResult.SkipToken) {
            $graphResult = Search-AzGraph -Query $Query -First $BatchSize -SkipToken $graphResult.SkipToken
        }
        else {
            $graphResult = Search-AzGraph -Query $Query -First $BatchSize
        }

        $baseData.Resources = $graphResult.Data

        if($graphResult.Data.Count -gt 0) {
            $currentMinSeq = $graphResult.Data[0].narcosisseq
            $currentMaxSeq = $graphResult.Data[$graphResult.Data.Count - 1].narcosisseq

            if($null -ne $previousSeq) {
                if($lastSeq -lt $currentMaxSeq) {
                    if($tasks.Count -gt 0) {
                        Write-Host "Waiting for $($tasks.Count) $Action tasks to complete"
                        Wait-DurableTask -Task $tasks
                    }
                    $tasks = @()
                }
            }

            Write-Host "Running $Action task for $($graphResult.Data.Count) VMs and sequence $currentMinSeq - $currentMaxSeq"
            # execute batch
            $tasks += Invoke-DurableActivity -FunctionName 'StartStopActivity' -Input $baseData -NoWait
            $previousSeq = $currentMinSeq
        }

        if ($graphResult.Data.Count -lt $BatchSize) {
            break;
        }
    }

    # wait for all jobs to complete
    if($tasks.Count -gt 0) {
        Write-Host "Waiting for $($tasks.Count) $Action tasks to complete"
        Wait-DurableTask -Task $tasks
    }
    $tasks = @()
}


# stopping eligable vms
ExecuteGraphQuery -Query $StopQuery -BatchSize $BatchSize -Action "stop" -FromTime $Context.Input.FromTime -UntilTime $Context.Input.UntilTime

# starting eligable vms
ExecuteGraphQuery -Query $StartQuery -BatchSize $BatchSize -Action "start" -FromTime $Context.Input.FromTime -UntilTime $Context.Input.UntilTime


"Done"

