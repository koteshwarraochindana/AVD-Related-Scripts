<#
.SYNOPSIS
  Delete unused FSLogix profiles in Azure Files for AVD.

.DESCRIPTION
  This script removes FSLogix profile VHDX files from Azure Files
  when they do not belong to any active Entra ID (Azure AD) user.

.NOTES
  ⚠️ This script deletes files permanently.
  Run the reporting script first before enabling deletion.
#>

# ===============================
# User Input Section
# ===============================
$StorageAccountName = "yourstorageaccount"
$ResourceGroupName  = "yourResourceGroup"
$FileShareName      = "profileshare"
$OutputReport       = "C:\Temp\DeletedProfilesReport.csv"
$DryRun             = $true   # <-- Change to $false to actually delete

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
# Get Active Azure AD Users
# ===============================
Write-Host "Collecting active Azure AD users..." -ForegroundColor Cyan
$activeUsers = Get-AzureADUser -All $true | Where-Object { $_.AccountEnabled -eq $true } | 
               Select-Object UserPrincipalName

# ===============================
# Compare Profiles and Delete Stale Ones
# ===============================
$deletedProfiles = @()

foreach ($profile in $profiles) {
    # Extract username from FSLogix profile filename
    $username = ($profile.Name -split "_")[1] -replace ".vhdx",""

    # Check if this username exists in Azure AD
    $userMatch = $activeUsers | Where-Object { $_.UserPrincipalName -like "$username*" }

    if (-not $userMatch) {
        Write-Host "Stale profile found: $username ($($profile.Name))" -ForegroundColor Yellow
        
        if (-not $DryRun) {
            # Delete file from Azure Files
            Remove-AzStorageFile -ShareName $FileShareName `
                                 -Path ($profile.CloudFileDirectory + "/" + $profile.Name) `
                                 -Context $ctx -Force
            Write-Host "Deleted: $($profile.Name)" -ForegroundColor Red
        }

        # Log deleted profile
        $deletedProfiles += [PSCustomObject]@{
            ProfileFile   = $profile.Name
            UserName      = $username
            LastModified  = $profile.LastModified
            DeletedOn     = (Get-Date).ToString("u")
            Action        = $(if ($DryRun) { "DryRun - Not Deleted" } else { "Deleted" })
        }
    }
}

# ===============================
# Export Deletion Report
# ===============================
if ($deletedProfiles.Count -gt 0) {
    $deletedProfiles | Export-Csv -Path $OutputReport -NoTypeInformation -Force
    Write-Host "Deletion report saved to $OutputReport" -ForegroundColor Green
} else {
    Write-Host "No stale profiles found!" -ForegroundColor Green
}
