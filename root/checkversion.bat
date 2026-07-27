REM .\checkversion.bat rd-rml.ain

@echo off
setlocal

if "%~1"=="" (
    echo Usage: %~nx0 file.ain
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$b=[IO.File]::ReadAllBytes('%~1');$r=New-Object IO.BinaryReader((New-Object IO.MemoryStream(,$b)));$o=[ordered]@{};$o.File='%~nx1';$o.Size=$b.Length;$o.Version=$r.ReadInt32();$o.MapVersion=$r.ReadInt32();$o.HeaderHex=($b[0..([Math]::Min(31,$b.Length-1))]|%%{'{0:X2}'-f$_})-join ' ';$o|ConvertTo-Json|Set-Content '%~dpn1.json';Write-Host 'Exported to %~dpn1.json'"