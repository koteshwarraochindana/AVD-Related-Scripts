<#
.SYNOPSIS
  Identify stale FSLogix profiles in Azure Files for AVD, based on security group membership.

.DESCRIPTION
  This script lists all FSLogix profile VHDX files in an Azure Files share,
  compares them against members of specified Entra ID (Azure AD) security groups,
  and flags profiles as stale if:
    1. The user is not in any of the specified groups, OR
    2. The profile hasn't been modified in X days.

.NOTES
  Requires Az and AzureAD modules.
  Install-Module Az -Scope CurrentUser
  Install-Module AzureAD -Scope CurrentUser
#>

# ===============================
# User Input Section
# ===============================
$StorageAccountName = "yourstorageaccount"
$ResourceGroupName  = "yourResourceGroup"
$FileShareName      = "profileshare"
$OutputReport       = "C:\Temp\StaleProfilesReport.csv"
$StaleDaysThreshold = 90   # Mark profiles stale if not modified in X days

# Security groups (replace with your AVD groups)
$GroupsToCheck = @(
    "AVD-HostPool1-Users",
    "AVD-HostPool2-Users"
)

# ===============================
# Connect to Azure
# ===============================
Write-Host "Connecting to Azure..." -ForegroundColor Cyan
Connect-AzAccount | Out-Null
Connect-AzureAD   | Out-Null

# ===============================
# Get Storage Context
# ===============================
$key = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName)[0].Value
$ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $key

# ===============================
# List All FSLogix Profile VHDX Files
# ===============================
Write-Host "Collecting FSLogix profiles from Azure Files..." -ForegroundColor Cyan
$profiles = Get-AzStorageFile -ShareName $FileShareName -Context $ctx -Recurse |
            Where-Object { $_.Name -like "*.vhdx" } |
            Select-Object Name, CloudFileDirectory, LastModified

# ===============================
# Collect Members from Security Groups
# ===============================
Write-Host "Collecting users from specified security groups..." -ForegroundColor Cyan
$groupMembers = @()

foreach ($groupName in $GroupsToCheck) {
    $group = Get-AzureADGroup -SearchString $groupName
    if ($group) {
        $members = Get-AzureADGroupMember -ObjectId $group.ObjectId -All $true |
                   Where-Object { $_.UserPrincipalName } |
                   Select-Object -ExpandProperty UserPrincipalName
        $groupMembers += $members
        Write-Host "Found $($members.Count) users in group $groupName" -ForegroundColor Green
    } else {
        Write-Host "Group not found: $groupName" -ForegroundColor Red
    }
}

$groupMembers = $groupMembers | Sort-Object -Unique

# ===============================
# Compare Profiles with Group Members + LastModified
# ===============================
$staleProfiles = @()
$cutoffDate = (Get-Date).AddDays(-$StaleDaysThreshold)

foreach ($profile in $profiles) {
    $username = ($profile.Name -split "_")[1] -replace ".vhdx",""

    $reason = @()
    if ($groupMembers -notcontains $username) {
        $reason += "User not in allowed security groups"
    }
    if ($profile.LastModified -lt $cutoffDate) {
        $reason += "Last modified more than $StaleDaysThreshold days ago"
    }

    if ($reason.Count -gt 0) {
        $staleProfiles += [PSCustomObject]@{
            ProfileFile   = $profile.Name
            UserName      = $username
            LastModified  = $profile.LastModified
            Reason        = ($reason -join "; ")
        }
    }
}

# ===============================
# Export Report
# ===============================
if ($staleProfiles.Count -gt 0) {
    Write-Host "Found $($staleProfiles.Count) stale profiles. Exporting report..." -ForegroundColor Yellow
    $staleProfiles | Export-Csv -Path $OutputReport -NoTypeInformation -Force
    Write-Host "Report saved to $OutputReport" -ForegroundColor Green
} else {
    Write-Host "No stale profiles found!" -ForegroundColor Green
}
