param(
    [string]$Action = "get", # get, set, remove, list
    [string]$Key = "",
    [string]$Value = "",
    [switch]$Secure
)

# Use a simple JSON file for credential storage
$credentialsPath = "$PSScriptRoot\build-credentials.json"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Get-Credentials {
    if (Test-Path $credentialsPath) {
        try {
            $content = Get-Content $credentialsPath | ConvertFrom-Json
            return $content
        }
        catch {
            Write-Log "Failed to read credentials: $_" "ERROR"
            return @{}
        }
    }
    return @{}
}

function Save-Credentials {
    param([hashtable]$Credentials)
    try {
        $Credentials | ConvertTo-Json -Depth 3 | Set-Content $credentialsPath
        Write-Log "Credentials saved successfully" "SUCCESS"
    }
    catch {
        Write-Log "Failed to save credentials: $_" "ERROR"
    }
}

function Encrypt-String {
    param([string]$PlainText)
    try {
        $secureString = ConvertTo-SecureString -String $PlainText -AsPlainText -Force
        $encrypted = ConvertFrom-SecureString -SecureString $secureString
        return $encrypted
    }
    catch {
        Write-Log "Encryption failed: $_" "ERROR"
        return $PlainText
    }
}

function Decrypt-String {
    param([string]$EncryptedText)
    try {
        $secureString = ConvertTo-SecureString -String $EncryptedText
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
        $plainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        return $plainText
    }
    catch {
        Write-Log "Decryption failed: $_" "ERROR"
        return $EncryptedText
    }
}

# Load existing credentials
$creds = Get-Credentials

switch ($Action.ToLower()) {
    "set" {
        if (-not $Key) {
            Write-Log "Key parameter required for set action" "ERROR"
            exit 1
        }
        
        if (-not $Value) {
            $Value = Read-Host "Enter value for '$Key'" -AsSecureString
            $Value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value))
        }
        
        if ($Secure) {
            $Value = Encrypt-String -PlainText $Value
            $creds[$Key] = @{
                "value" = $Value
                "encrypted" = $true
                "updated" = (Get-Date).ToString()
            }
        }
        else {
            $creds[$Key] = @{
                "value" = $Value
                "encrypted" = $false
                "updated" = (Get-Date).ToString()
            }
        }
        
        Save-Credentials -Credentials $creds
        Write-Log "Set credential '$Key'" "SUCCESS"
    }
    
    "get" {
        if (-not $Key) {
            Write-Log "Key parameter required for get action" "ERROR"
            exit 1
        }
        
        if ($creds.ContainsKey($Key)) {
            $credInfo = $creds[$Key]
            if ($credInfo.encrypted -eq $true) {
                $value = Decrypt-String -EncryptedText $credInfo.value
            }
            else {
                $value = $credInfo.value
            }
            Write-Output $value
        }
        else {
            Write-Log "Credential '$Key' not found" "ERROR"
            exit 1
        }
    }
    
    "remove" {
        if (-not $Key) {
            Write-Log "Key parameter required for remove action" "ERROR"
            exit 1
        }
        
        if ($creds.ContainsKey($Key)) {
            $creds.Remove($Key)
            Save-Credentials -Credentials $creds
            Write-Log "Removed credential '$Key'" "SUCCESS"
        }
        else {
            Write-Log "Credential '$Key' not found" "WARNING"
        }
    }
    
    "list" {
        if ($creds.Count -eq 0) {
            Write-Log "No stored credentials found" "INFO"
        }
        else {
            Write-Log "Stored credentials:" "INFO"
            $creds.Keys | ForEach-Object {
                $encrypted = if ($creds[$_].encrypted) { " (encrypted)" } else { "" }
                $updated = $creds[$_].updated
                Write-Log "  $_ - Updated: $updated$encrypted" "INFO"
            }
        }
    }
    
    default {
        Write-Log "Usage: credential-manager.ps1 -Action <get|set|remove|list> [-Key <keyname>] [-Value <value>] [-Secure]" "INFO"
        Write-Log "Examples:" "INFO"
        Write-Log "  Set password: .\credential-manager.ps1 -Action set -Key 'ssh-password' -Secure" "INFO"
        Write-Log "  Get password: .\credential-manager.ps1 -Action get -Key 'ssh-password'" "INFO"
        Write-Log "  List all: .\credential-manager.ps1 -Action list" "INFO"
    }
}