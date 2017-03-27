<#
.SYNOPSIS
Through this Automation script you can schedule a specific Resource Group Azure VM at specific times for resizing. 
 
 
 
It is suggested that you run 2 schedules, for example: 
 
At night hours, downscale to the lowest VM size for cost reasons. 
 
At the start of office hours, upscale to the usual size for productivity. 
 
 
 
This script is highly based on Kay Singh's script for Vertical Scaling, I added scheduling variables for practical use. 
 
Check his Runbook here: https://docs.microsoft.com/en-us/azure/virtual-machines/virtual-machines-linux-vertical-scaling-automation 
 
Note: Downtime of +- 4 minutes applies when the job starts. 

.DESCRIPTION
   This script will adjust the size of a Microsoft Azure virtual machine based on input given into the new schedule.

   When making a Schedule or doing a test run you are required to declare:
   * The desired to be VM Size
   * The Resource Group name of the VM that is to be changed
   * The name of the VM that is to be changed

   Below in the script at lines 120 and 122 you are required to declare:
   * A Credentials Asset
   * A Variable Asset with the Subscription ID in it

   
   This script is based on the runbook by Kay Singh, 75% of credit goes to him.
   https://gallery.technet.microsoft.com/scriptcenter/Vertically-scale-up-an-d6c15c54
   
.PARAMETER VirtualMachineName
     String name of the VM that will be changed in size.

.PARAMETER VMSize
     String name of the desired size the specified VM will be receiving.

Allowed 'VMSize'values:

DS:
Standard_DS1,Standard_DS2,Standard_DS3,Standard_DS4,Standard_DS11,Standard_DS12,Standard_DS13,Standa
rd_DS14,Standard_DS1_v2,Standard_DS
2_v2,Standard_DS3_v2,Standard_DS4_v2,Standard_DS5_v2,Standard_DS11_v2,Standard_DS12_v2,Standard_DS13_v2,Standard_DS14_v2
,Standard_DS15_v2

A:
Standard_A0,Standard_A1,Standard_A2,Standard_A3,Standard_A5,Standard_A4,Standard_A6,Standard_A7,Basic_A0,Basic_A
1,Basic_A2,Basic_A3,Basic_A4, Standard_A1_v2,Standard_A2m_v2,Standard_A2_v2,Standard_A4m_v2,Standard_A4_v2,Standard_A8m_v2,Standard_A8_v2,
Standard_A8,Standard_A9,Standard_A10,Standard_A11

D:
Standard_D1_v2,Standard_D2_v2,Standard_D3_v2,Standard_D4_v2,Standard_D5_v2,Standard_D11_v2,
Standard_D12_v2,Standard_D13_v2,Standard_D14_v2,Standard_D15_v2,Standard_D1,Standard_D2,Standard_D3,Standard_D4,Standard_D11,Standard_D12,Standard_D13,Standard_D14

F:
Standard_F1,Standard_F2,Standard_F4,Standard_F8,Standard_F16,Standard_F1s,Standard_F2s,Standard_F4s,Standard_F8s,Standard_F16s

H:
Standard_H8,Standard_H16,Standard_H8m,Standard_H16m,Standard_H16r,Standard_H16mr

G:
Standard_G1,Standard_G2,Standard_G3,Standard_G4,Standard_G5,

GS:
Standard_GS1,Standard_GS2,Standard_GS3,Standard_GS4,Standard_GS5

NV:
Standard_NV6,Standard_NV12,Standard_NV24

NOTE: It is likely that not all of these options apply to your specific VM, follow the guideline below to check the sizes that apply to your VM.
> To see the possible sizes for your specific VM check the following: Click the specified VM in the dashboard -> Virtual Machine Overview -> Size and note what is available

.PARAMETER ResourceGroup
    String that contains the name of Resource Group where your specified VM is a part of.
                 
 
.NOTES
	Author: Siebert Timmermans
	Last Updated: 27/03/2017
    Version 1.1 - Updated User Experience and logging. 

    DO NOT FORGET THE CREDENTIAL/KEY DECLARATION IN THE SCRIPT BELOW
#>


workflow VMScheduledScaler
{
    
        Param
    (         

        [parameter(Mandatory=$true)]
        [String] $VirtualMachineName,
        
        [parameter(Mandatory=$true)]
        [string] $VMSize,

        [parameter(Mandatory=$true)]
        [string] $ResourceGroup
   
    )



    InlineScript { 


# Introduction Output part 1
    $VERSION = "1.1"
    $currentTime = (Get-Date).AddHours(2)#.ToUniversalTime()
    Write-Output "Runbook started. Version: $VERSION" 
    Write-Output "Schedule received for current time in CET [$($currentTime.ToString("dddd dd MMM yyyy HH:mm:ss"))]. Running job..."

# Credentials and Subscription ID declaration, DO NOT FORGET TO FILL IN THESE!
    $Cred = Get-AutomationPSCredential -Name 'siebertsCredentials'
    $null = Add-AzureRmAccount -Credential $Cred -ErrorAction Stop
	$SubId = Get-AutomationVariable -Name 'AzureKey'
	$null = Set-AzureRmContext -SubscriptionId $SubId -ErrorAction Stop

# Introduction Output part 2
    if($SubId.length -gt 0) 
        { 
            Write-Output "Specified subscription ID: [$SubID]" 
        } 
    else 
        { 
            throw "No subscription name was specified. Create a subscription Variable Asset and add it to the Runbook in the declaration variables manually." 
        } 

    if($Cred -ne $null) 
            { 
                Write-Output "Attempting to authenticate as: [$($Cred.UserName)]" 
            } 
            else 
            { 
                throw "No automation credential name was specified. Create a Credential Asset and add it to the Runbook in the declaration variables manually." 
            }

    Write-Output "Specified VM name: [$Using:VirtualMachineName]"
    Write-Output "Specified VM Resource Group: [$Using:ResourceGroup]"
    Write-Output "Desired VM size: [$Using:VMSize]"
    Write-Output "`n----------------------------------------------------------------------"


# Check if specified VM can be found
    try {
    $vm = Get-AzureRmVm -ResourceGroupName $Using:ResourceGroup -VMName $Using:VirtualMachineName -ErrorAction Stop
    } catch {
    Write-Error "Virtual Machine not found"
    exit
    }

# Output current VM Size
    $currentVMSize = $vm.HardwareProfile.vmSize
    
    Write-Output "`nFound the specified Virtual Machine: $Using:VirtualMachineName"
    Write-Output "Current size: $currentVMSize"

# Change to new VM Size and report
	$newVMSize = $Using:VMSize
    
        Write-Output "`nNew size will be: $newVMSize"
        Write-Output "`n----------------------------------------------------------------------"
            
        $vm.HardwareProfile.VmSize = $newVMSize
        Update-AzureRmVm -VM $vm -ResourceGroupName $Using:ResourceGroup
        
        $updatedVm = Get-AzureRmVm -ResourceGroupName $Using:ResourceGroup -VMName $Using:VirtualMachineName
        $updatedVMSize = $updatedVm.HardwareProfile.vmSize
        
        Write-Output "`n----------------------------------------------------------------------"
        Write-Output "`nSize updated to: $updatedVMSize"



    

    }

}


