<#
.SYNOPSIS
    PowerShell script for recovering soft-deleted mailboxes in Exchange Online
.DESCRIPTION
    This script will connect to Exchange Online, search for a specific softdeleted mailbox.
    If the softdeleted mailbox is found the script will create a new Office365 User and license it with a P1 Standard Email license.
    The new mailbox created will be named: "recovered-" + "<old mailbox identity>"

    Once the new mailbox has been created the script will start restoring the deleted mailbox into the new mailbox.

    At then end the mailbox will assign access to the mailbox, for a specified user.
.NOTES
    This script requires credentials with access to MSOnline and ExchangeOnlineManagement with PowerShell

    Modules used:
    - MSOnline
    - ExchangeOnlineManagement
.LINK
    Specify a URI to a help page, this will show when Get-Help -Online is used.
.EXAMPLE
    .\RecoverOldMailboxes.ps1 -DeletedMailboxUPN mail01@domain.com -GrantAccessTo admin@domain.com -Credential $Creds

    This example will create a new mailbox named: recovered-mail01 and assign it with an EXCHANGESTANDARD license.
    It will then restore the mailbox mail01 into recovered-mail01 and assign the user admin@domain.com full access to the new
    created mailbox.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String]$DeletedMailboxUPN,
    [Parameter(Mandatory=$true)]
    [String]$GrantAccessTo,
    [Parameter(Mandatory=$false)]
    [String]$License = "EXCHANGESTANDARD",
    [Parameter(Mandatory=$true)]
    [System.Management.Automation.PSCredential]$Credential
)

# Importing Modules
Import-Module ExchangeOnlineManagement
Import-Module MSOnline


# Connecting to Exchange Online
if(Get-Command Get-MailboxPermission -ErrorAction SilentlyContinue){
    Write-Host "Already connected to Exchange Online"
}
else {
    Write-Warning -Message "No connection to Exchange Online was found... Connecting now"
    try {
        Connect-ExchangeOnline -Credential $Creds
    }
    catch {
        Write-Warning -Message "Failed connecting to Exchange Online"
        Write-Error -Message "$($_)"
        Exit
    }
}

# Connecting to MSOnline
if(Get-MsolDomain -ErrorAction SilentlyContinue){
    Write-Host "Already connected to MSOnline"
}
else {
    Write-Warning -Message "No connection to MSOnline was found... Connecting now"
    try {
        Connect-MsolService -Credential $Creds
    }
    catch {
        Write-Warning -Message "Failed connecting to MSOnline"
        Write-Error -Message "$($_)"
        Exit
    }
}



# Searching for the deleted Mailbox
Write-Host "Searching for soft deleted mailbox.."
$DeletedMailbox = Get-Mailbox -SoftDeletedMailbox $DeletedMailboxUPN
$NewMailboxIdentity = "recovered-" + $DeletedMailboxUPN.split("@")[0]
$NewMailboxUPN = $NewMailboxIdentity + "@" + $DeletedMailboxUPN.split("@")[1]
Write-Host "$($DeletedMailbox.UerPrincipalName)"

# Logic if mailbox was found then create the new recovered mailbox user
switch($DeletedMailbox)
{
    $null {
        Write-Warning -Message "No mailbox was found with UPN: $($DeletedMailboxUPN), exiting script now!"
        Exit
    }
    default {
        $OldGUID = $DeletedMailbox.ExchangeGuid.Guid
        Write-Host "Found ExhcangeGUID: $($OldGUID) for mailbox: $($DeletedMailboxUPN)"
        try {
            New-MsolUser -UserPrincipalName $NewMailboxUPN `
                -DisplayName $NewMailboxIdentity `
                -FirstName "Recovered" `
                -LastName $NewMailboxIdentity `
                -UsageLocation "DK" `
                -LicenseAssignment (Get-MsolAccountSku | ? {$_.AccountSkuId -match $License} | Select-Object -ExpandProperty AccountSkuId)
            
            Write-Host "Creating new mailbox user for hosting the recovered mailbox"
        }
        catch {
            Write-Warning -Message "Failed creating the new user for hosting the recovered mailbox"
            Write-Error -message "$($_)"
            Exit
        }

        $i = 0
        While(!(Get-EXOMailbox $NewMailboxIdentity -ErrorAction SilentlyContinue) -and ($i -le 10)) {
            Start-Sleep -s 15
            $i++
        }

        $NewMailboxUser = Get-Mailbox  $NewMailboxIdentity
        
    }
}

switch($NewMailboxUser)
{  
    $null {
        Write-Warning -Message "No new mailbox user was found.. Exiting script"
    }
    default {
        $NewGUID = $NewMailboxUser.ExchangeGuid.Guid
        Write-Host "Found ExhcangeGUID: $($NewGUID) for mailbox: $($NewMailboxUPN)"

        Write-Host "Initiating Copy of data from: $($DeletedMailboxUPN), to: $($NewMailboxUser.UserPrincipalName)"
        try {
            New-MailboxRestoreRequest -SourceMailbox $OldGUID -TargetMailbox $NewGUID -AllowLegacyDNMismatch
            Write-Host "Sucessfully recovered mailbox: $($DeletedMailboxUPN), to new mailbox: $($NewMailboxUser.UserPrincipalName)"
        }
        catch {
            Write-Warning -Message "Failed mailbox restore!"
            Write-Error -Message "$($_)"
            Exit
        }

        Write-Host "Initiating granting permissions to the restored mailbox for user: $($GrantAccessTo)"
        try {
            $NewMailboxUser | Add-MailboxPermission -User $GrantAccessTo -AccessRights FullAccess -InheritanceType All -AutoMapping $true
            Write-Host "Successfully granted access to mailbox: $($DeletedMailbox), for user: $($GrantAccessTo)"
        }
        catch {
            Write-Warning "Failed granting permissions to recovered mailbox for user: $($GrantAccessTo)"
            Write-Error $($_)
            Exit
        }
    } 
}