# PowerShell Script to Enable Windows Hello and Biometrics

# Function to enable registry keys
function Enable-RegistryKey {
    param (
        [string]$Path,
        [string]$Name,
        [string]$ValueType,
        [int]$Value
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $ValueType -Force
    Write-Output "Set registry key $Path\$Name to $Value"
}

# Enable registry settings
Enable-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Biometrics" -Name "Enabled" -ValueType "DWORD" -Value 1
Enable-RegistryKey -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "AllowDomainPINLogon" -ValueType "DWORD" -Value 1

# Function to create INF file for secedit
function Create-INFFile {
    param (
        [string]$FilePath,
        [string[]]$Policies
    )
    $content = @"
[Unicode]
Unicode=yes
[Version]
signature="\$CHICAGO$"
Revision=1
[Registry Values]
$($Policies -join "`n")
"@
    $content | Out-File -FilePath $FilePath -Force
    Write-Output "Created INF file at $FilePath"
}

# Create INF file for Group Policy settings
$Policies = @(
    'MACHINE\Software\Policies\Microsoft\PassportForWork\PINComplexity\UsePINRecovery=4,1',
    'MACHINE\Software\Policies\Microsoft\PassportForWork\PINComplexity\UseBiometrics=4,1',
    'MACHINE\Software\Policies\Microsoft\PassportForWork\PINComplexity\UseHardwareSecurityDevice=4,1',
    'MACHINE\Software\Policies\Microsoft\PassportForWork\PINComplexity\UseWindowsHelloForBusiness=4,1',
    'MACHINE\Software\Policies\Microsoft\PassportForWork\PINComplexity\ConfigureDynamicLockFactors=4,1',
    'MACHINE\Software\Policies\Microsoft\Biometrics\Enabled=4,1',
    'MACHINE\Software\Policies\Microsoft\Biometrics\AllowDomainUserLogon=4,1',
    'MACHINE\Software\Policies\Microsoft\Biometrics\AllowBiometric=4,1',
    'MACHINE\Software\Policies\Microsoft\Biometrics\AllowUserLogon=4,1',
    'MACHINE\Software\Policies\Microsoft\Windows\System\AllowDomainPINLogon=4,1',
    'MACHINE\Software\Policies\Microsoft\System\AllowConveniencePINSignIn=4,1'
)
$INFFilePath = "$env:TEMP\EnableWindowsHello.inf"
Create-INFFile -FilePath $INFFilePath -Policies $Policies

# Apply INF file using secedit with timeout
try {
    Write-Output "Applying INF file using secedit..."
    $process = Start-Process -FilePath "secedit" -ArgumentList "/configure /db $env:TEMP\EnableWindowsHello.sdb /cfg $INFFilePath /overwrite" -NoNewWindow -PassThru
    $process.WaitForExit(300) # Wait for 5 minutes
    if (-not $process.HasExited) {
        $process.Kill()
        throw "Secedit process timed out and was terminated."
    }
    Write-Output "Applied INF file using secedit successfully."
} catch {
    Write-Output "Failed to apply INF file using secedit: $_"
}

# Clean up
try {
    Write-Output "Cleaning up temporary files..."
    if (Test-Path -Path $INFFilePath) {
        Remove-Item -Path $INFFilePath -Force
    }
    if (Test-Path -Path "$env:TEMP\EnableWindowsHello.sdb") {
        Remove-Item -Path "$env:TEMP\EnableWindowsHello.sdb" -Force
    }
    Write-Output "Cleanup completed."
} catch {
    Write-Output "Failed to clean up temporary files: $_"
}

Write-Output "Windows Hello and Biometrics settings have been enabled."
