<#
.SYNOPSIS
  Identify unused FSLogix profiles in Azure Files for AVD.

.DESCRIPTION
  This script lists all FSLogix VHDX profiles in an Azure Files share,
  compares them against active Entra ID (Azure AD) users, 
  and exports a CSV report of stale profiles (profiles without an active user).

.NOTES
  Run this script with Az and AzureAD modules installed.
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
            Select-Object Name, LastModified

# ===============================
# Get Active Azure AD Users
# ===============================
Write-Host "Collecting active Azure AD users..." -ForegroundColor Cyan
$activeUsers = Get-AzureADUser -All $true | Where-Object { $_.AccountEnabled -eq $true } | 
               Select-Object UserPrincipalName

# ===============================
# Compare Profiles with Active Users
# ===============================
$staleProfiles = @()

foreach ($profile in $profiles) {
    # Extract username from FSLogix profile filename
    # Format usually: Profile_username.sid.vhdx
    $username = ($profile.Name -split "_")[1] -replace ".vhdx",""

    # Check if this username exists in Azure AD
    $userMatch = $activeUsers | Where-Object { $_.UserPrincipalName -like "$username*" }

    if (-not $userMatch) {
        $staleProfiles += [PSCustomObject]@{
            ProfileFile   = $profile.Name
            UserName      = $username
            LastModified  = $profile.LastModified
            Status        = "STALE - No Active User"
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
