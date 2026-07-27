REM .\replace.bat file.ain v mv

@echo off
setlocal

if "%~3"=="" (
    echo Usage: %~nx0 file.ain new_version new_mapversion
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$file='%~1';$version=[int]%~2;$map=[int]%~3;$b=[IO.File]::ReadAllBytes($file);$ms=New-Object IO.MemoryStream(,$b);$bw=New-Object IO.BinaryWriter($ms);$ms.Position=0;$bw.Write($version);$bw.Write($map);$bw.Close();[IO.File]::WriteAllBytes($file,$ms.ToArray());Write-Host 'Updated:' $file 'Version=' $version 'MapVersion=' $map"