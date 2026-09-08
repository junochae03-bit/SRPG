param([ValidateRange(1,3)][int]$Slot=1,[switch]$QuickStart,[switch]$Hidden,[int]$Duration=0)
$ErrorActionPreference='Stop'
$rpgEngine=Join-Path $PSScriptRoot 'tools\godot\Godot_v4.6-stable_win64.exe'
$rpgGame=Join-Path $PSScriptRoot 'game'
$rpgLogs=Join-Path $PSScriptRoot 'runtime\logs'
New-Item -ItemType Directory -Force -Path $rpgLogs | Out-Null
if (-not (Test-Path -LiteralPath $rpgEngine)) {
    if ($env:GODOT_EXE -and (Test-Path -LiteralPath $env:GODOT_EXE)) { $rpgEngine=$env:GODOT_EXE }
    else {
        $rpgCommand=Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($rpgCommand) { $rpgEngine=$rpgCommand.Source }
        else { throw 'Install Godot 4.6 and set GODOT_EXE or add godot to PATH. See README.md.' }
    }
}
$rpgArguments=@('--path',('"{0}"' -f $rpgGame),'--log-file',('"{0}"' -f (Join-Path $rpgLogs "play-slot-$Slot.log")),'--',"--slot=$Slot")
if ($QuickStart) { $rpgArguments+='--play' }
if ($Duration -gt 0) { $rpgArguments+="--duration=$Duration" }
if ($Hidden) {
    Start-Process -FilePath $rpgEngine -ArgumentList $rpgArguments -WindowStyle Hidden -Wait
} else {
    Start-Process -FilePath $rpgEngine -ArgumentList $rpgArguments | Out-Null
}
