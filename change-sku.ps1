# Install the Az module if not already installed
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -AllowClobber -Force
}

# Import the Az module
Import-Module Az

# Log in to your Azure account using device code authentication
Connect-AzAccount -UseDeviceAuthentication

# Set the subscription context
Set-AzContext -SubscriptionName "sub-rs-corp-avd-0001"

# Define the CSV file path
$csvFilePath = "C:\path\to\your\hostnames.csv"

# Import the CSV file
$hostsData = Import-Csv -Path $csvFilePath

foreach ($host in $hostsData) {
    # Get the VM details
    $vm = Get-AzVM -ResourceGroupName "rs-rg-corp-avd-uat-vdi-eus2-01" -Name $host.Hostname
    
    # Check if the current SKU matches the old SKU specified in the CSV
    if ($vm.HardwareProfile.VmSize -eq $host.OldSKU) {
        # Update the SKU
        $vm.HardwareProfile.VmSize = $host.NewSKU

        # Apply the changes
        Update-AzVM -ResourceGroupName "rs-rg-corp-avd-uat-vdi-eus2-01" -VM $vm

        Write-Output "Updated SKU for $($host.Hostname) from $($host.OldSKU) to $($host.NewSKU)"
    } else {
        Write-Output "SKU for $($host.Hostname) does not match the old SKU $($host.OldSKU). Skipping update."
    }
}

Write-Output "SKU update process completed for all hosts."
