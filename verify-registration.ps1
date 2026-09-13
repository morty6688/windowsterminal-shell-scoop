$ErrorActionPreference = 'Stop'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'install.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) { throw ($parseErrors | Out-String) }
foreach ($f in $ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]}, $false)) {
    . ([scriptblock]::Create($f.Extent.Text))
}
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'uninstall.ps1'), [ref]$tokens, [ref]$parseErrors)
if ($parseErrors) { throw ($parseErrors | Out-String) }
# Isolate registration from the real registry, icons, settings, and elevation.
function New-Item { param($Path,[switch]$Force,$ItemType) }
function Test-Path {
    param($Path,$LiteralPath)
    $candidate = if ($LiteralPath) { $LiteralPath } else { $Path }
    $script:values.ContainsKey("$candidate|(Default)")
}
function Get-Item {
    param($LiteralPath)
    $key = [pscustomobject]@{ RegistryPath=$LiteralPath }
    $key | Add-Member -MemberType ScriptMethod -Name GetValue -Value {
        param($name)
        $lookup = if ($name -eq '') { '(Default)' } else { $name }
        $script:values["$($this.RegistryPath)|$lookup"]
    }
    $key
}
function New-ItemProperty { param($Path,$Name,$PropertyType,$Value,[switch]$Force) $script:values["$Path|$Name"]=$Value }
function Remove-ItemProperty { param($LiteralPath,$Name,$ErrorAction) $script:removed += "$LiteralPath|$Name" }
function GetProgramFilesFolder { 'C:\Users\test\scoop\apps\windows-terminal\current' }
function Generate-HelperScript { param($cache) }
function GetWindowsTerminalIcon { 'C:\cache\wt.ico' }
function GetProfileIcon { 'C:\cache\wt.ico' }
function GetActiveProfiles {
    [pscustomobject]@{guid='{574e775e-4f2a-5b96-ac1e-a2962a402336}';name='PowerShell'}
    [pscustomobject]@{guid='{595b2812-4099-4984-bfdf-033c46168b6a}';name='bash'}
}
foreach ($layout in 'Default','Flat','Mini') {
    $script:values=@{}; $script:removed=@()
    CreateMenuItems 'C:\Terminal Folder\wt.exe' $layout $false
    $commands=@($values.GetEnumerator() | Where-Object Key -like '*\command|(Default)')
    $expectedCount = if ($layout -eq 'Mini') { 4 } else { 8 }
    if ($commands.Count -ne $expectedCount) { throw "$layout command count: $($commands.Count)" }
    foreach ($command in $commands) {
        $expected=if($command.Key -like '*\Background\*' -or $command.Key -like '*.Background.*') {'%V\.'} else {'%1\.'}
        if (-not $command.Value.Contains('"'+$expected+'"')) { throw "Wrong folder argument: $($command.Value)" }
        if ($command.Value -match 'AppsFolder|DelegateExecute|powershell.*Start-Process') { throw 'Unexpected activation' }
    }
    if ($layout -eq 'Default') {
        if (@($values.Keys | Where-Object {$_ -like '*|SubCommands'}).Count -ne 4 -or $removed.Count -ne 4) { throw 'Cascades not migrated' }
        foreach ($parent in @($values.GetEnumerator() | Where-Object Key -like '*|SubCommands')) {
            if (-not $parent.Value) { throw 'Empty CommandStore references' }
            foreach ($verb in $parent.Value.Split(';')) {
                $key = "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\$verb\command|(Default)"
                if (-not $values.ContainsKey($key)) { throw "Unresolved CommandStore reference: $verb" }
            }
        }
    }
    Write-Output "$layout PASS: $expectedCount commands, selected/background arguments, normal/elevated registration"
}
Write-Output 'PowerShell syntax PASS: install.ps1 and uninstall.ps1. No live registry changes or UI launches.'
