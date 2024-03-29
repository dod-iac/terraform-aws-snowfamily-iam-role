@echo off

rem # =================================================================
rem #
rem # Work of the U.S. Department of Defense, Defense Digital Service.
rem # Released as open source under the MIT License.  See LICENSE file.
rem #
rem # =================================================================

rem isolate changes to local environment
setlocal

rem create local bin folder if it doesn't exist
if not exist "%~dp0bin" (
  mkdir %~dp0bin
)

rem update PATH to include local bin folder
PATH=%~dp0bin;%PATH%

rem set common variables for targets

set "USAGE=Usage: %~n0 [clean|format_terraform|help|update_docs]"

rem if no target, then print usage and exit
if [%1]==[] (
  echo|set /p="%USAGE%"
  exit /B 1
)

if %1%==clean (

  REM remove bin directory
  if exist %~dp0bin (
    rd /s /q %~dp0bin
  )

  REM remove temp directory
  if exist %~dp0temp (
    rd /s /q %~dp0temp
  )

  exit /B 0
)

if %1%==format_terraform (

  where terraform >nul 2>&1 || (
    echo|set /p="terraform is missing."
    exit /B 1
  )

  powershell "%~dp0powershell\format-terraform.ps1"

  exit /B 0
)

if %1%==help (
  echo|set /p="%USAGE%"
  exit /B 1
)

if %1%==update_docs (

  where terraform-docs >nul 2>&1 || (
    echo|set /p="terraform-docs is missing/"
    exit /B 1
  )

  powershell "%~dp0powershell\update-docs.ps1"

  exit /B 0
)

echo|set /p="%USAGE%"
exit /B 1
