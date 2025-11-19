@echo off
echo HP Image Assistant - Download and Install Critical Driver Updates
echo =============================================================

REM Create directories including logs and driver download folders
if not exist "c:\temp\hpia" mkdir "c:\temp\hpia"
if not exist "c:\temp\hpia\driver downloads" mkdir "c:\temp\hpia\driver downloads"
if not exist "c:\temp\hpia\logs" mkdir "c:\temp\hpia\logs"

echo Creating directories...
echo.

REM Download HPIA SoftPaq from HP website
echo Downloading HP Image Assistant from HP website...
echo This may take a few minutes depending on your internet connection...

powershell -Command "& {$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri 'https://ftp.ext.hp.com/pub/softpaq/sp158001-158500/sp158107.exe' -OutFile 'c:\temp\hpia\sp158107.exe'}"

REM Check if download was successful
if not exist "c:\temp\hpia\sp158107.exe" (
    echo ERROR: Failed to download HP Image Assistant SoftPaq!
    echo Please check your internet connection and try again.
    pause
    exit /b 1
)

echo HP Image Assistant SoftPaq downloaded successfully.
echo.

REM Extract HPIA SoftPaq without waiting (extraction runs asynchronously)
echo Extracting HP Image Assistant...
start "" "c:\temp\hpia\sp158107.exe" /s /e /f "c:\temp\hpia"

REM Wait for extraction to complete using ping instead of timeout
set WAIT=0
:WaitForExtraction
if exist "c:\temp\hpia\HPImageAssistant.exe" goto ExtractionComplete
if %WAIT% GEQ 30 goto ExtractionComplete
echo Waiting for extraction... (%WAIT%/30 seconds)
ping 127.0.0.1 -n 6 >nul
set /a WAIT=%WAIT%+5
goto WaitForExtraction

:ExtractionComplete
REM Verify extraction
if not exist "c:\temp\hpia\HPImageAssistant.exe" (
    echo ERROR: HP Image Assistant extraction failed!
    pause
    exit /b 1
)

echo HP Image Assistant extracted successfully.
echo.

REM Run HP Image Assistant to analyze and install critical driver updates with logging enabled
echo Running HP Image Assistant to install critical driver updates...
echo Logging enabled in c:\temp\hpia\logs
echo This may take several minutes...
echo.

"c:\temp\hpia\HPImageAssistant.exe" /Operation:Analyze /Category:Drivers /Selection:all /Action:Install /Silent /AutoCleanup /Debug /LogFolder:"c:\temp\hpia\logs" /ReportFolder:"c:\temp\hpia\logs" /SoftpaqDownloadFolder:"c:\temp\hpia\driver downloads"

REM Check the exit code
if %errorlevel% equ 0 (
    echo.
    echo Critical driver updates completed successfully!
) else if %errorlevel% equ 1168 (
    echo.
    echo Critical driver updates completed successfully!
) else (
    echo.
    echo Warning: HPIA completed with exit code %errorlevel%
)

echo.
echo Process completed. Check the logs and reports folder for details.
echo Logs location: c:\temp\hpia\logs
echo Downloaded drivers location: c:\temp\hpia\driver downloads
echo.
pause
