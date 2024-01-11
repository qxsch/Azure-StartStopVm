$narcovmrg = "startstopvm"
$functionAppName = "narcovm"

if(Test-Path .\functionapp.zip -PathType Leaf) {
    Write-Host "Removing old functionapp.zip"
    Remove-Item .\functionapp.zip -Force | Out-Null
}
Write-Host "Creating functionapp.zip"
Compress-Archive -Path .\functionapp\* -DestinationPath .\functionapp.zip -Force

# checking settings
$settings = Get-AzFunctionAppSetting -ResourceGroupName $narcovmrg -Name $functionAppName 
if((-not $settings.SCM_DO_BUILD_DURING_DEPLOYMENT) -or $settings.SCM_DO_BUILD_DURING_DEPLOYMENT -ne "false") {
    Write-Host "Disabling build during deployment"
    Update-AzFunctionAppSetting -ResourceGroupName $narcovmrg -Name $functionAppName -AppSetting @{"SCM_DO_BUILD_DURING_DEPLOYMENT" = "false"} | Out-Null
}
Write-Host "Publishing function app"
Publish-AzWebApp -ResourceGroupName $narcovmrg -Name $functionAppName -ArchivePath .\functionapp.zip -Force | Out-Null

