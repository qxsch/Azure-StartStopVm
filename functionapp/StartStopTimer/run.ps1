# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
  Write-Host "PowerShell timer is running late!"
}

if($null -eq $Timer.ScheduleStatus) {
  throw "ScheduleStatus is null - this usally indicates, that interval is below 1 minute"
}


$FromTime  = $Timer.ScheduleStatus.Last.ToUniversalTime()
$UntilTime = $Timer.ScheduleStatus.Next.ToUniversalTime()
$ts = ($UntilTime - $FromTime)
if($ts.TotalMinutes -gt 1200) {
    throw "Date range must be less than 20 hours"
}

if($untilTime -gt $currentUTCtime) {
    Write-Host "Time is running ahead of schedule, adjusting window to current time..."
    $UntilTime = $currentUTCtime
    $FromTime  = $UntilTime - $ts    
}

Write-Host "TimeSpan for Start / Stop Evaluations: $FromTime - $UntilTime"

$InstanceId = Start-DurableOrchestration -FunctionName "StartStopOrchestrator" -Input @{
    FromTime = $FromTime
    UntilTime = $UntilTime
}
Write-Host "Started StartStop orchestration with ID = '$InstanceId'"
