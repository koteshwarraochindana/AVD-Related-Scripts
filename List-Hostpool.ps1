foreach ($workspace in $workspaces) {

$hostPools = Get-NmeWorkspaceSessionHost -SubscriptionId $workspace.Id.SubscriptionId -ResourceGroup $workspace.Id.ResourceGroup -WorkspaceName $workspace.Id.Name

Write-Host "Workspace Name: $($workspace.WorkspaceName)"

foreach ($hp in $hostPools) {

Write-Host "Host Pool Workspaca: $($hp.WorkspaceName)"

Write-Host "Host Pool Name: $($hp.Hostpool.HostpoolName)"

Write-Host "Host Pool Resource Group: $($hp.Hostpool.ResourceGroup)"

Write-Host "Host Pool Subscription: $($hp.Hostpool.Subscription)"

# Add any additional desired information about the host pool here

}

}
