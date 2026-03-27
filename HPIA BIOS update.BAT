@echo off
setlocal ENABLEDELAYEDEXPANSION

echo HP Image Assistant - BIOS Update Only
echo ======================================

REM Create directories
if not exist "c:\temp\hpia" mkdir "c:\temp\hpia"
if not exist "c:\temp\hpia\driver downloads" mkdir "c:\temp\hpia\driver downloads"
if not exist "c:\temp\hpia\logs" mkdir "c:\temp\hpia\logs"
echo Directories ready.
echo.

REM Generate datetime stamp for log folder (format: DD-MM-YYYY_HH-MM)
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set DT=%%I
set LOGSTAMP=%DT:~6,2%-%DT:~4,2%-%DT:~0,4%_%DT:~8,2%-%DT:~10,2%
set LOGFOLDER=c:\temp\hpia\logs\%LOGSTAMP%
if not exist "%LOGFOLDER%" mkdir "%LOGFOLDER%"
echo Log folder: %LOGFOLDER%
echo.

REM Get latest HPIA SoftPaq from HP catalog
echo Checking for latest HPIA version...
powershell -Command "& {$ProgressPreference='SilentlyContinue'; try { $response=Invoke-WebRequest -Uri 'https://ftp.ext.hp.com/pub/softpaq/sp-CONTENTindex.xml' -UseBasicParsing; $xml=[xml]$response.Content; $hpia=$xml.SelectSingleNode('//Softpaq[Name[contains(text(),\"HP Image Assistant\")]]'); if ($hpia) { $filename='sp'+$hpia.Id+'.exe'; Write-Host \"Latest HPIA: $filename\"; $filename | Out-File -FilePath 'c:\temp\hpia\latest_filename.txt' -Encoding ascii } else { Write-Host 'Not found in catalog'; exit 1 } } catch { Write-Host 'Catalog error, using fallback...'; 'sp158107.exe' | Out-File -FilePath 'c:\temp\hpia\latest_filename.txt' -Encoding ascii } }"

REM Read filename
if exist "c:\temp\hpia\latest_filename.txt" (
    set /p HPIA_FILENAME=<"c:\temp\hpia\latest_filename.txt"
    echo HPIA filename: !HPIA_FILENAME!
) else (
    echo Using fallback filename...
    set HPIA_FILENAME=sp158107.exe
)
echo.

REM Construct download URL
set SOFTPAQ_NUM=!HPIA_FILENAME:~2,6!
set RANGE_START=158001
set RANGE_END=158500

if !SOFTPAQ_NUM! GEQ 158001 if !SOFTPAQ_NUM! LEQ 158500 ( set RANGE_START=158001 & set RANGE_END=158500 )
if !SOFTPAQ_NUM! GEQ 158501 if !SOFTPAQ_NUM! LEQ 159000 ( set RANGE_START=158501 & set RANGE_END=159000 )
if !SOFTPAQ_NUM! GEQ 159001 if !SOFTPAQ_NUM! LEQ 159500 ( set RANGE_START=159001 & set RANGE_END=159500 )
if !SOFTPAQ_NUM! GEQ 159501 if !SOFTPAQ_NUM! LEQ 160000 ( set RANGE_START=159501 & set RANGE_END=160000 )
if !SOFTPAQ_NUM! GEQ 160001 if !SOFTPAQ_NUM! LEQ 160500 ( set RANGE_START=160001 & set RANGE_END=160500 )
if !SOFTPAQ_NUM! GEQ 160501 if !SOFTPAQ_NUM! LEQ 161000 ( set RANGE_START=160501 & set RANGE_END=161000 )

set DOWNLOAD_URL=https://ftp.ext.hp.com/pub/softpaq/sp!RANGE_START!-!RANGE_END!/!HPIA_FILENAME!
echo Download URL: !DOWNLOAD_URL!
echo.

REM Download HPIA
echo Downloading HPIA - this may take a few minutes...
powershell -Command "& {$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile 'c:\temp\hpia\!HPIA_FILENAME!' } catch { Write-Host 'Primary download failed, trying fallback...'; try { Invoke-WebRequest -Uri 'https://ftp.ext.hp.com/pub/softpaq/sp158001-158500/sp158107.exe' -OutFile 'c:\temp\hpia\!HPIA_FILENAME!' } catch { Write-Host 'All downloads failed' } } }"

if not exist "c:\temp\hpia\!HPIA_FILENAME!" (
    echo ERROR: HPIA download failed!
    exit /b 1
)
echo HPIA downloaded successfully.
echo.

REM Extract HPIA
echo Extracting HPIA...
start "" "c:\temp\hpia\!HPIA_FILENAME!" /s /e /f "c:\temp\hpia"

set WAIT=0
:WaitForExtraction
if exist "c:\temp\hpia\HPImageAssistant.exe" goto ExtractionComplete
if !WAIT! GEQ 60 goto ExtractionTimeout
echo Waiting for extraction... (!WAIT!/60s)
ping 127.0.0.1 -n 6 >nul
set /a WAIT=!WAIT!+5
goto WaitForExtraction

:ExtractionTimeout
echo ERROR: HPIA extraction timed out!
exit /b 1

:ExtractionComplete
echo HPIA extracted successfully.
echo.

REM Run HPIA - BIOS only, silent, ignore generic OS error
echo Running HPIA BIOS update...
echo Logs: %LOGFOLDER%
echo This may take several minutes...
echo.
"c:\temp\hpia\HPImageAssistant.exe" /Operation:Analyze /Category:BIOS /Selection:All /Action:Install /Silent /AutoCleanup /Debug /IgnoreGenericOsError /LogFolder:"%LOGFOLDER%" /ReportFolder:"%LOGFOLDER%" /SoftpaqDownloadFolder:"c:\temp\hpia\driver downloads"

set HPIA_EXIT=!errorlevel!
echo.

REM Log exit code result
if !HPIA_EXIT! equ 0 (
    echo BIOS update completed successfully - no reboot required.
) else if !HPIA_EXIT! equ 1168 (
    echo No applicable BIOS updates found - device is up to date.
) else if !HPIA_EXIT! equ 256 (
    echo No BIOS recommendations - device is up to date.
) else if !HPIA_EXIT! equ 257 (
    echo BIOS analysis complete - no action taken.
) else if !HPIA_EXIT! equ 3010 (
    echo BIOS update installed - reboot required.
) else if !HPIA_EXIT! equ 3020 (
    echo BIOS update installed - reboot in progress.
) else if !HPIA_EXIT! equ 4102 (
    echo BIOS update installed - reboot required.
) else if !HPIA_EXIT! equ 4103 (
    echo BIOS update installed after network retry - reboot required.
) else (
    echo HPIA completed with exit code: !HPIA_EXIT!
)

echo.
echo Logs location: %LOGFOLDER%
echo Driver downloads: c:\temp\hpia\driver downloads

REM Clean up temp files
if exist "c:\temp\hpia\latest_filename.txt" del "c:\temp\hpia\latest_filename.txt"

exit /b !HPIA_EXIT!