param($Context)

# $Context.Input.FromTime
# $Context.Input.UntilTime

Import-Module Az.ResourceGraph -ErrorAction Stop

<#
Use provisioningState == Succeeded to avoid shutting down VMs that are being created or updated

The following table lists the possible values for the powerState property.
Meaning             Property value
------------------  -------------------------------
Deallocated	        PowerState/deallocated
Deallocating        PowerState/deallocating
Running             PowerState/running
Starting            PowerState/starting
Stopped             PowerState/stopped
Stopping            PowerState/stopping
Unknown             PowerState/unknown
#>
$StopQuery = "resources 
| where ['type'] == 'microsoft.compute/virtualmachines' and tags['narcovm:stop:time'] != '' and properties.provisioningState=~'succeeded' and properties.extended.instanceView.powerState.code contains 'running'
| extend  narcosisseq = case(isnull(toint(tags['narcovm:stop:sequence'])), 1000000, toint(tags['narcovm:stop:sequence'])), narcosistime = tags['narcovm:stop:time'], narcosistimezone = tags['narcovm:timezone']
| project id, name, narcosisseq, narcosistime, narcosistimezone
| order by narcosisseq asc"
$StartQuery = "resources 
| where ['type'] == 'microsoft.compute/virtualmachines' and tags['narcovm:start:time'] != '' and properties.provisioningState=~'succeeded' and (properties.extended.instanceView.powerState.code contains 'deallocated' or properties.extended.instanceView.powerState.code contains 'stopped')
| extend  narcosisseq = case(isnull(toint(tags['narcovm:start:sequence'])), 1000000, toint(tags['narcovm:start:sequence'])), narcosistime = tags['narcovm:start:time'], narcosistimezone = tags['narcovm:timezone']
| project id, name, narcosisseq, narcosistime, narcosistimezone
| order by narcosisseq asc"

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
Write-Host "Executing stop query with $batchSize batch size and from $($Context.Input.FromTime) until $($Context.Input.UntilTime)"
ExecuteGraphQuery -Query $StopQuery -BatchSize $BatchSize -Action "stop" -FromTime $Context.Input.FromTime -UntilTime $Context.Input.UntilTime

# starting eligable vms
Write-Host "Executing start query with $batchSize batch size and from $($Context.Input.FromTime) until $($Context.Input.UntilTime)"
ExecuteGraphQuery -Query $StartQuery -BatchSize $BatchSize -Action "start" -FromTime $Context.Input.FromTime -UntilTime $Context.Input.UntilTime

Write-Host "Orchestrator done"

"Done"

