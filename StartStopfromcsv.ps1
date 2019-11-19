#<#
#.Description
#	This script starts or shuts down the virtual machines stored in a csv file which in turn is stored in the blob storage for the automation account to access it.
#   The script uses the default automation connection to connect to the subscription of the automation account and then starts/stops the virtual machines in order.
#   If the Start operation is chosen, it starts the machines starting from the top 0f the csv
#   If the Stop operation is chosen, it starts the machines starting from the bottom of the csv
#   This script only works within the subscription
#   
#   The origin .csv file has 2 columns: ResourceGroup and VMName
##>

workflow startSystems
{

param(
  [Parameter(Mandatory=$True)]
  [string]$resourceGroupName,
  [Parameter(Mandatory=$True)]
  [string]$storageAccountName,
  [Parameter(Mandatory=$True)]
  [string]$containter,
  [Parameter(Mandatory=$True)]
  [string]$fileName,
  [Parameter(Mandatory=$True)]
  [ValidateSet("Start","Stop")] 
  [string]$operation
 )
  
    if($operation -ne "Start" -and $operation -ne "Stop")
    {
        Throw "$($operation) is not a valid operation. Please use Start/Stop."
    }

    $Conn = Get-AutomationConnection -Name AzureRunAsConnection
    Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
    -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

    #Get Storage Account
    Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -StorageAccountName $storageAccountName

    #Get CSV File
    $now = Get-Date
    $sasToken = New-AzureStorageContainerSASToken -Name $containter -Permission r -StartTime $now.AddMinutes(-5) -ExpiryTime $now.AddMinutes(15)
    $blobPath = "https://$storageAccountName.blob.core.windows.net/$containter/$fileName$sasToken"
    $webClient = New-Object System.Net.WebClient
    $VMsCsvString = $webClient.DownloadString($blobPath)
    $VMs = ConvertFrom-Csv -InputObject $VMsCsvString
    
    Write-Output "Operation $operation VMs from Blob File started"
    #Get Connection Details
    
    #Start/Stop VMs

    if($operation -eq "Start")
    {
        Foreach ($vm in $VMs) 
        {
            Write-Output "Starting $($vm.VMName)" 
            Start-AzureRmVM -ResourceGroupName $vm.ResourceGroup -Name $vm.VMName 
            Do{
                Write-Output "Starting $($vm.VMName)"
                $VmStatus = ((Get-AzureRMVM -ResourceGroupName $resourceGroupName -Name $vm.VMName -Status).Statuses[1]).Code #check if its done starting the VM
            } Until ($VmStatus -eq 'PowerState/running')
        }
    } 
    else
    {
        $VMsLength= ($VMs | Measure-Object).Count
        $ReverseVMs =($VMs[($VMlength-1)..0]) #flip the .csv file
        Foreach ($vm in $ReverseVMs)
        {
            Write-Output "Stopping $($vm.VMName)" 
            Stop-AzureRmVM -ResourceGroupName $vm.ResourceGroup -Name $vm.VMName -Force
            Do{
                Write-Output "Stopping $($vm.VMName)"
                $VmStatus = ((Get-AzureRMVM -ResourceGroupName $resourceGroupName -Name $vm.VMName -Status).Statuses[1]).Code  #check if its done stopping the VM
            } Until ($VmStatus -eq 'PowerState/deallocated')
        }
    }



    Write-Output "Operation $operation VMs from Blob File completed"
}

