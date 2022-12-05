<#
.DESCRIPTION
    Script for generating a JSON file for the migration of a multiple homefolders to their respective OneDrive for Business location.
.EXAMPLE
    .\generate-json-migrationfile.ps1 -ListOfUsersFile .\ListOfUsers.txt
.PARAMETER OnedriveUrl
    The URL of the OneDrive for Business site.
.PARAMETER OnedriveUrlTemplate
    The domain part of the onedrive url
.PARAMETER TargetList
    The name of the target list in the OneDrive for Business site.
.PARAMETER TargetListRelativePath
    The folder inside onedrive where all files should be migrated to
.PARAMETER JsonOutputPath
    The path where the JSON file should be saved.
.PARAMETER ListOfUsersFile
    The path to the file containing the list of users.
#>
param (
    [Parameter(Mandatory=$false)]
    [string]$OnedriveUrl = "",#"https://christianscriptingchris-my.sharepoint.com/personal",
    [Parameter(Mandatory=$false)]
    [string]$OnedriveUrlTemplate = "", #"scriptingchris_tech",
    [Parameter(Mandatory=$false)]
    [string]$TargetList = "Documents",
    [Parameter(Mandatory=$false)]
    [string]$TargetListRelativePath = "migration",
    [Parameter(Mandatory=$false)]
    [string]$HomeFolderLocation = "", #"\\adc01\homefolders$",
    [Parameter(Mandatory=$false)]
    [string]$JsonOutputPath = "", #".\migration.json",
    [Parameter(Mandatory=$false)]
    [string]$ListOfUsersFile
)


Function New-OneDriveUrl {
    <#
    .DESCRIPTION
        Helper function for formatting the user OneDrive URL
    .EXAMPLE
        New-OneDriveUrl -OnedriveUrl "https://my_sharepoint_site-my.sharepoint.com/personal" -OnedriveUrlTemplate "scriptingchris_tech" -Username "chr"
        
        Will Output:
            https://my_sharepoint_site-my.sharepoint.com/personal/chr_scriptingchris_tech
    .PARAMETER OnedriveUrl
        The base URL of the OneDrive for Business site
        example: https://my_sharepoint_site-my.sharepoint.com/personal
    .PARAMETER OnedriveUrlTemplate
        The 'domain' part for the OneDrive for Business site url
        example: scriptingchris_tech
    .PARAMETER Username
        The username of the user
        example: chr
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$OnedriveUrl,
        [Parameter(Mandatory=$true)]
        [string]$OnedriveUrlTemplate,
        [Parameter(Mandatory=$true)]
        [string]$Username
    )

    $completeUrl = "$($OnedriveUrl)/$($Username)_$($OnedriveUrlTemplate)"
    return $completeUrl
}


Function Get-AllUsernamesFromHomeFolders {
    <#
    .DESCRIPTION
        Helper function for getting all usernames from the home folders
    .EXAMPLE
        Get-AllUsernamesFromHomeFolders -HomeFolderLocation ".\homefolders"

        Will Output:
            chr
            joh
            mar
    .PARAMETER HomeFolderLocation
        The location of the home folders
        example: \\server01\homefolders
    #>
    param (
        [Parameter(Mandatory=$true)]
        [string]$HomeFolderLocation
    )

    $users = Get-ChildItem -Path $HomeFolderLocation -Directory | Select-Object -ExpandProperty Name
    return $users
}


Function Get-MigrationJsonObject {
    <#
    .DESCRIPTION
        Helper function for generating the migration JSON object
    .EXAMPLE
        Get-MigrationJsonObject -OnedriveUrl "https://my_sharepoint_site-my.sharepoint.com/personal" -OnedriveUrlTemplate "scriptingchris_tech" -Username "chr" -TargetList "Documents" -TargetListRelativePath "migration"

        Will Output:
            {
                "sourceUrl": "\\server01\homefolders\chr",
                "targetSiteUrl": "https://my_sharepoint_site-my.sharepoint.com/personal/chr_scriptingchris_tech",
                "targetListTitle": "Documents",
                "targetFolderRelativeUrl": "migration"
            }
    .PARAMETER Users
        Array of all the users which should be added to the migration Task

        example:
            chr
            tdj
            pli
    .PARAMETER ListOfUsers
        txt file with all the users which are allowed to be migrated

        example:
            chr
            tdj
            pli
    #>
    
    
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Users,
        [Parameter(Mandatory=$false)]
        [Array]$ListOfUsersFile
    )

    $Tasks = New-Object System.Collections.ArrayList
    $ListOfUsers = Get-Content $ListOfUsersFile

    if ($ListOfUsers) {
        Foreach($user in $users) {
            if ($ListOfUsers -contains $user) {
                $targetUrl = New-OneDriveUrl -OnedriveUrl $OnedriveUrl -OnedriveUrlTemplate $OnedriveUrlTemplate -Username $user
        
                $object = @{
                    "SourcePath" = "$($HomeFolderLocation)\$($user)"
                    "TargetPath" = $targetUrl
                    "TargetList" = $TargetList
                    "TargetListRelativePath" = $TargetListRelativePath
                }
                $Tasks.Add($object) | Out-Null
            }
        }
    }
    else {
        Foreach($user in $users) {
            $targetUrl = New-OneDriveUrl -OnedriveUrl $OnedriveUrl -OnedriveUrlTemplate $OnedriveUrlTemplate -Username $user
    
            $object = @{
                "SourcePath" = "$($HomeFolderLocation)\$($user)"
                "TargetPath" = $targetUrl
                "TargetList" = $TargetList
                "TargetListRelativePath" = $TargetListRelativePath
            }
            $Tasks.Add($object) | Out-Null
        }
    }

    $jsonObject = @{
        "Tasks" = $Tasks
    } | ConvertTo-Json -Depth 4

    Return $jsonObject
}


$users = Get-AllUsernamesFromHomeFolders -HomeFolderLocation $HomeFolderLocation
if ($ListOfUsersFile) {
    $jsonObject = Get-MigrationJsonObject -Users $users -ListOfUsersFile $ListOfUsersFile | Out-File -FilePath ".\migration.json" -Encoding UTF8
}
else {
    $jsonObject = Get-MigrationJsonObject -Users $users | Out-File -FilePath ".\migration.json" -Encoding UTF8
}
