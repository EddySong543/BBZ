param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Import', 'Test', 'Tool', 'Probe')]
    [string]$Mode,

    [string]$Target,

    [ValidateRange(5, 1800)]
    [int]$TimeoutSeconds = 0,

    [string]$ProbeOutput = 'D:\Game\BoBoZan\_probe_output',

    [switch]$Visible
)

$ErrorActionPreference = 'Stop'

$GodotExecutable = 'D:\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$LogRoot = 'D:\Game\BoBoZan\_probe_output\godot_logs'

if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found: $GodotExecutable"
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'project.godot') -PathType Leaf)) {
    throw "Godot project root is invalid: $ProjectRoot"
}

if ($TimeoutSeconds -eq 0) {
    $TimeoutSeconds = switch ($Mode) {
        'Import' { 120 }
        'Test' { 180 }
        'Tool' { 120 }
        'Probe' { 120 }
    }
}

if (($Mode -eq 'Tool' -or $Mode -eq 'Probe') -and [string]::IsNullOrWhiteSpace($Target)) {
    throw "Mode $Mode requires -Target."
}

New-Item -ItemType Directory -Path $LogRoot -Force | Out-Null
if ($Mode -eq 'Probe') {
    New-Item -ItemType Directory -Path $ProbeOutput -Force | Out-Null
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$LogFile = Join-Path $LogRoot ("{0}_{1}.log" -f $Mode.ToLowerInvariant(), $Timestamp)
$GodotArguments = [System.Collections.Generic.List[string]]::new()

if ($Mode -ne 'Probe') {
    $GodotArguments.Add('--headless')
}
$GodotArguments.Add('--path')
$GodotArguments.Add($ProjectRoot)
$GodotArguments.Add('--log-file')
$GodotArguments.Add($LogFile)

switch ($Mode) {
    'Import' {
        $GodotArguments.Add('--import')
    }
    'Test' {
        $GodotArguments.Add('-s')
        $GodotArguments.Add('res://addons/gut/gut_cmdln.gd')
        $GodotArguments.Add('-gconfig=res://tests/.gutconfig.json')
        $GodotArguments.Add('-gexit')
    }
    'Tool' {
        $GodotArguments.Add('--script')
        $GodotArguments.Add($Target)
    }
    'Probe' {
        $GodotArguments.Add($Target)
        $GodotArguments.Add('--')
        $GodotArguments.Add('probe-output=' + $ProbeOutput.Replace('\', '/'))
    }
}

# SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX.
# The child inherits this mode, so automated crashes become an exit code/log instead of a blocking dialog.
if (-not ('BbzGodot.NativeMethods' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace BbzGodot {
    public static class NativeMethods {
        [DllImport("kernel32.dll")]
        public static extern uint SetErrorMode(uint uMode);
    }
}
'@
}

$PreviousErrorMode = [BbzGodot.NativeMethods]::SetErrorMode(0x0001 -bor 0x0002)
$GodotProcess = $null
try {
    $StartArguments = @{
        FilePath = $GodotExecutable
        ArgumentList = $GodotArguments.ToArray()
        PassThru = $true
    }
    if (-not $Visible) {
        $StartArguments.WindowStyle = 'Hidden'
    }
    $GodotProcess = Start-Process @StartArguments
}
finally {
    [void][BbzGodot.NativeMethods]::SetErrorMode($PreviousErrorMode)
}

try {
    if (-not $GodotProcess.WaitForExit($TimeoutSeconds * 1000)) {
        try {
            # This object is exactly the process created by Start-Process above.
            # Never enumerate or terminate any pre-existing/user-started Godot process here.
            # Windows PowerShell 5.1 exposes Kill() but not the newer Kill(entireProcessTree) overload.
            $GodotProcess.Kill()
            $GodotProcess.WaitForExit(5000) | Out-Null
        }
        catch {
            Write-Warning "Failed to terminate timed-out Godot process $($GodotProcess.Id): $_"
        }
        throw "Godot $Mode timed out after $TimeoutSeconds seconds. The launched process $($GodotProcess.Id) was terminated. Log: $LogFile"
    }

    $GodotProcess.Refresh()
    $ExitCode = $GodotProcess.ExitCode
    if ($ExitCode -ne 0) {
        throw "Godot $Mode failed with exit code $ExitCode. Log: $LogFile"
    }

    if ($Mode -eq 'Test') {
        $TestLog = Get-Content -Raw -Encoding UTF8 -LiteralPath $LogFile
        if ($TestLog -notmatch 'All tests passed!') {
            throw "GUT exited without the expected success marker. Log: $LogFile"
        }
    }

    [pscustomobject]@{
        Mode = $Mode
        ProcessId = $GodotProcess.Id
        ExitCode = $ExitCode
        LogFile = $LogFile
        Target = $Target
    }
}
finally {
    $GodotProcess.Dispose()
}
