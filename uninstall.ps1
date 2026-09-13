#Requires -Version 6

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Default', 'Flat', 'Mini')]
    [string] $Layout = 'Default',
    [Parameter()]
    [switch] $PreRelease
)

$ErrorActionPreference = 'Stop'

# Based on @nerdio01's version in https://github.com/microsoft/terminal/issues/1060

if ((Test-Path "Registry::HKEY_CLASSES_ROOT\Directory\shell\MenuTerminal") -and
    -not (Test-Path "Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\MenuTerminal")) {
    Write-Error 'A legacy machine-wide MenuTerminal registration exists. This script only removes the current-user installation and its CommandStore entries; inspect the legacy HKLM menu registration separately.'
    exit 1
}

# CommandStore is machine-wide; delete only this user's project-owned verbs.
$store = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell'
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$ownedVerbs = @()
if ($Layout -eq 'Default' -and (Test-Path -LiteralPath $store)) {
    $ownedVerbs = @(Get-ChildItem -LiteralPath $store | Where-Object { $_.PSChildName.StartsWith("WindowsterminalShellScoop.$sid.") })
    if ($ownedVerbs.Count -gt 0) {
        $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Run uninstall.ps1 in an elevated PowerShell session to remove CommandStore entries.'
        }
    }
}

$localCache = "$Env:LOCALAPPDATA\windowsterminal-shell-scoop\Cache"
if (Test-Path $localCache) {
    $expectedCache = [IO.Path]::GetFullPath("$Env:LOCALAPPDATA\windowsterminal-shell-scoop\Cache")
    $resolvedCache = (Resolve-Path -LiteralPath $localCache).ProviderPath
    if ($resolvedCache -ne $expectedCache -or (Get-Item -LiteralPath $localCache).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Unexpected cache path: $resolvedCache"
    }
    Remove-Item -LiteralPath $resolvedCache -Recurse
}

Write-Host "Use" $layout "layout."

if ($layout -eq "Default") {
    foreach ($verb in $ownedVerbs) {
        Remove-Item -LiteralPath $verb.PSPath -Recurse -Force -ErrorAction Stop
    }
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\MenuTerminal' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\MenuTerminal' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\MenuTerminal\shell' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\MenuTerminalAdmin' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\MenuTerminalAdmin' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\ContextMenus\MenuTerminalAdmin\shell' -Recurse -ErrorAction Ignore | Out-Null
} elseif ($layout -eq "Flat") {
    $rootKey = 'HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell'
    foreach ($key in Get-ChildItem -Path "Registry::$rootKey") {
       if (($key.Name -like "$rootKey\MenuTerminal_*") -or ($key.Name -like "$rootKey\MenuTerminalAdmin_*")) {
          Remove-Item "Registry::$key" -Recurse -ErrorAction Ignore | Out-Null
       }
    }

    $rootKey = 'HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell'
    foreach ($key in Get-ChildItem -Path "Registry::$rootKey") {
       if (($key.Name -like "$rootKey\MenuTerminal_*") -or ($key.Name -like "$rootKey\MenuTerminalAdmin_*")) {
          Remove-Item "Registry::$key" -Recurse -ErrorAction Ignore | Out-Null
       }
    }
} elseif ($layout -eq "Mini") {
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\MenuTerminalMini' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\shell\MenuTerminalAdminMini' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\MenuTerminalMini' -Recurse -ErrorAction Ignore | Out-Null
    Remove-Item -Path 'Registry::HKEY_CURRENT_USER\SOFTWARE\Classes\Directory\Background\shell\MenuTerminalAdminMini' -Recurse -ErrorAction Ignore | Out-Null
}

Write-Host "Windows Terminal uninstalled from Windows Explorer context menu."
