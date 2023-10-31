# App C import file hashes script
# Author: Graham Harvey grahamh@vmware.com

# get the App Control server info
Write-Host "Enter your App Control Server fqdn or IP address"
Write-Host "NOTE: You must include the https:// part of the URL"
Write-Host "For example: https://appcontrol.myorg.internal"
$appc_server = Read-Host "AppC Server" 

# get the API credentials
$appc_creds = Read-Host "Enter your API Token"

# Set the X-Auth-Token
$headers = @{
    "X-Auth-Token" = $appc_creds
    "Content-Type" = "application/json"
}

# Input request for csv
# CSV file format should be as follows
# name,description,hash,fileName,fileState
# name of the rule or file name, the description of the rule, the SHA1 or SHA256 hash, the name of the file (only used if no hash is provded), the state that you want the file to be in
# Currently App Control API only accepts Banned for new file rules created via the API
Write-Host ""
Write-Host "You must import a CSV file (comma separated)."
Write-Host "The CSV mush have the following headers: name,description,hash,fileName,fileState"
Write-Host "The hash can be either SHA1 or SHA256 and the state must be Banned."
Write-Host "WARNING: This script currently does not validate the contents of the CSV, any file that does not meet the"
Write-Host "         above requirements will result in an import failure."
Write-Host ""
Write-Host "WARNING: This script currently applies file Bans to All Policies."
Write-Host ""
$CSV = Read-Host -Prompt "Please enter the path to the CSV file you want to use"

if ($CSV.StartsWith('"') -and $CSV.EndsWith('"'))
{
    $CSV = $CSV.Trim('"')
}

# CSV parsing and array creation to use in API request below
$CSVImport = Import-Csv -Path $CSV

Write-Host "Connecting to"$appc_server "using" $appc_creds "for credentials and this data:"
$CSVImport | Format-Table
# Inform the user that Unapproved rules will be ignored and that Approval rules will have the file name value removed,
# and that Approval Rules with a file name but no hash will be completely ignored and not submitted to the App Control Server,
# and that the App Control API does not accept a filename when a hash is provided.
foreach ($line in $CSVImport) {
    #check if any Unapproved lines exist and warn user that those lines are ignored.
    if ($line.fileState -eq "Unapproved") {
        Write-Host "NOTE: Any lines with a fileState of Unapproved will be ignored as files are Unapproved by default."
        Write-Host ""
    }
    #check if any Unapprove lines exist and warn user that those lines are ignored.
    elseif ($line.fileState -eq "Unapprove") {
        Write-Host "NOTE: Any lines with a fileState of Unapproved will be ignored as files are Unapproved by default."
        Write-Host ""
    }
    #check if any Approve lines exist and the hash does not exist then warn user that the entire line will be ingored.
    elseif ($line.fileState -eq "Approve"-and ([string]::IsNullOrEmpty($line.hash))) {
        Write-Host "NOTE: Approval Rules require a hash and do not accept file names."
        Write-Host "This line will be ignored:" $line.name $line.fileName $line.fileState
        Write-Host ""
    }
    #check if any Approved lines exist and the hash does not exist then warn user that the entire line will be ingored.
    elseif ($line.fileState -eq "Approved"-and ([string]::IsNullOrEmpty($line.hash))) {
        Write-Host "NOTE: Approval Rules require a hash and do not accept file names"
        Write-Host "This line will be ignored:" $line.name $line.fileName $line.fileState
        Write-Host ""

    }
    #check if any Approved lines exist and warn user that the file name will be ignored and not submitted.
    elseif ($line.fileState -eq "Approved") {
        Write-Host "NOTE: Any lines with a fileState of Approved cannot use a file name and therefore that value will be ignored."
        Write-Host ""
    }
    #check if any Approve lines exist and warn user that the file name will be ignored and not submitted.
    elseif ($line.fileState -eq "Approve") {
        Write-Host "NOTE: Any lines with a fileState of Approved cannot use a file name and therefore that value will be ignored."
        Write-Host ""
    }
    #check if any Ban lines exist with a hash and warn them that the filename will be ingored and not submitted.
    elseif ($line.fileState -eq "Ban" -and ([string]::IsNullOrEmpty($line.hash))) {
        Write-Host "NOTE: The filename is ignored if the file rule includes a hash."
        Write-Host ""
    }
    #check if any Banned lines exist with a hash and warn them that the filename will be ingored and not submitted.
    elseif ($line.fileState -eq "Banned" -and ([string]::IsNullOrEmpty($line.hash))) {
        Write-Host "NOTE: The filename is ignored if the file rule includes a hash."
        Write-Host ""
    }
}

#Ask the use if the above submission looks correct to the and wait for a Y before continuing
Write-Host "Does the above look correct?"
$continue = Read-Host -Prompt "Y/N"

# If N is entered ask the user to correct their CSV file and try again.
if ($continue -eq "N") {Write-Host ""
    Write-Host "Please correct your CSV file and try again"
}
# If Y is entered, begin the fileRule creation
else {
    # Convert the File State word to supported values in App Control API
    foreach ($line in $CSVImport) {
        if ($line.fileState -eq "Unapproved") {
           $line.fileState = 1
        }
        elseif ($line.fileState -eq "Approved") {
           $line.fileState = 2
           $line.fileName = ""
        }
        elseif ($line.fileState -eq "Approve") {
            $line.fileState = 2
            $line.fileName = ""
        }
        elseif ($line.fileState -eq "Ban") {
            $line.fileState = 3
        }
        elseif ($line.fileState -eq "Banned") {
            $line.fileState = 3
        }
    }
    # Post the Fule Rule for each row of the CSV file
    foreach ($row in $CSVImport) {
        # Convert each like to a Json object
        $hashImportBody = ($row | ConvertTo-Json -Depth 1)
        # Check PS version and use -SkipCertificateCheck if PS v7 is used
        if ($PSVersionTable.PSVersion -le "5.2") {
            # Need to tell older version of PowerShell to trust a self-signed cert
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
            # Post each line as a stadalone file rule as App Control Rile Rule API only accepts first ent
            $fileRuleCreateResponse = Invoke-RestMethod -Uri $appc_server"/api/bit9platform/v1/fileRule" -Method "POST" -Headers $headers -Body $hashImportBody -ContentType "application/json"
        }
        else {
            # Post each line as a stadalone file rule as App Control Rile Rule API only accepts first ent
            $fileRuleCreateResponse = Invoke-RestMethod -SkipCertificateCheck -Uri $appc_server"/api/bit9platform/v1/fileRule" -Method "POST" -Headers $headers -Body $hashImportBody -ContentType "application/json"
        }
        # tell the user what was posted.
        Write-Host "this is what is POSTed: "$hashImportBody
    }
}
