param (
    [Parameter(Mandatory=$true)]
    [string]$OnedriveUrl = "https://christianscriptingchris-my.sharepoint.com/personal",
    [Parameter(Mandatory=$true)]
    [string]$OnedriveUrlTemplate = "scriptingchris_tech",
    [Parameter(Mandatory=$true)]
    [string]$TargetList = "Documents",
    [Parameter(Mandatory=$true)]
    [string]$HomeFolderLocation = ".\homefolders",
    [Parameter(Mandatory=$true)]
    [string]$JsonOutputPath = ".\migration.json"
)


Function New-OneDriveUrl {
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
    param (
        [Parameter(Mandatory=$true)]
        [string]$HomeFolderLocation
    )

    $users = Get-ChildItem -Path $HomeFolderLocation -Directory | Select-Object -ExpandProperty Name
    return $users
}


Function Get-MigrationJsonObject {
    param (
        [Parameter(Mandatory=$true)]
        [Array]$Users
    )

    $Tasks = New-Object System.Collections.ArrayList
    Foreach($user in $users) {
        $targetUrl = New-OneDriveUrl -OnedriveUrl $OnedriveUrl -OnedriveUrlTemplate $OnedriveUrlTemplate -Username $user
    
        $object = @{
            "SourcePath" = "$($HomeFolderLocation)\$($user)"
            "TargetPath" = $targetUrl
            "TargetList" = $TargetList
        }
        $Tasks.Add($object) | Out-Null
    }

    $jsonObject = @{
        "Tasks" = $Tasks
    } | ConvertTo-Json -Depth 4

    Return $jsonObject
}


$users = Get-AllUsernamesFromHomeFolders -HomeFolderLocation $HomeFolderLocation
$jsonObject = Get-MigrationJsonObject -Users $users | Out-File -FilePath ".\migration.json" -Encoding UTF8