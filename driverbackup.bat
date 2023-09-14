@ECHO off
:init
 setlocal DisableDelayedExpansion
 set cmdInvoke=1
 set winSysFolder=System32
 set "batchPath=%~dpnx0"
 rem this works also from cmd shell, other than %~0
 for %%k in (%0) do set batchName=%%~nk
 set "vbsGetPrivileges=%temp%\OEgetPriv_%batchName%.vbs"
 setlocal EnableDelayedExpansion

:checkPrivileges
  NET FILE 1>NUL 2>NUL
  if '%errorlevel%' == '0' ( goto gotPrivileges ) else ( goto getPrivileges )

:getPrivileges
  if '%1'=='ELEV' (echo ELEV & shift /1 & goto gotPrivileges)
  ECHO.
  ECHO **************************************
  ECHO Invoking UAC for Privilege Escalation
  ECHO **************************************

  ECHO Set UAC = CreateObject^("Shell.Application"^) > "%vbsGetPrivileges%"
  ECHO args = "ELEV " >> "%vbsGetPrivileges%"
  ECHO For Each strArg in WScript.Arguments >> "%vbsGetPrivileges%"
  ECHO args = args ^& strArg ^& " "  >> "%vbsGetPrivileges%"
  ECHO Next >> "%vbsGetPrivileges%"
  
  if '%cmdInvoke%'=='1' goto InvokeCmd 

  ECHO UAC.ShellExecute "!batchPath!", args, "", "runas", 1 >> "%vbsGetPrivileges%"
  goto ExecElevation

:InvokeCmd
  ECHO args = "/c """ + "!batchPath!" + """ " + args >> "%vbsGetPrivileges%"
  ECHO UAC.ShellExecute "%SystemRoot%\%winSysFolder%\cmd.exe", args, "", "runas", 1 >> "%vbsGetPrivileges%"

:ExecElevation
 "%SystemRoot%\%winSysFolder%\WScript.exe" "%vbsGetPrivileges%" %*
 exit /B 1

:gotPrivileges
 setlocal & cd /d %~dp0
 if '%1'=='ELEV' (del "%vbsGetPrivileges%" 1>nul 2>nul  &  shift /1)

REM -----------start script------------

setlocal enabledelayedexpansion

REM Check if the folder already exists
IF NOT exist "%~dp0backups" (
    mkdir %~dp0backups
    if errorlevel 1 (
        echo Failed to create folder 'backups' in '%~dp0'.
	pause
	exit /B 2
    ) else (
        echo Folder 'backups' created successfully in '%~dp0'.
	timeout /t 5
    )
)
REM Define the root directory to search -> use the script directory
SET  "root_directory=%~dp0backups\"
SET  count=0



:MENU
CLS
ECHO ...............................................
ECHO PRESS 1, 2 to select your task, or 0 to EXIT.
ECHO ...............................................
ECHO.
ECHO 1 - Backup drivers
ECHO 2 - Restore drivers
ECHO 0 - EXIT
ECHO.
SET  /P Menu=Type 1, 2 or 0 then press ENTER:
IF %Menu%==1 (
	GOTO BACKUP
) ELSE IF %Menu%==2 (
	GOTO RESTORE
) ELSE IF %Menu%==0 (
	GOTO EXIT
) ELSE (
	ECHO Invalid choice. Please try again.
	PAUSE
	GOTO MENU
)

:BACKUP
CLS
REM Request user input for folder name
:input_folder_name
set "folder_name="
set /p "folder_name=choose a (folder)name for the backup (or 'exit' to cancel): "

REM Check if the user entered 'exit' to cancel
if /i "%folder_name%"=="exit" (
    echo Operation canceled.
    goto EXIT
)

REM Check if the input is empty
IF "%folder_name%"=="" (
    ECHO Folder name cannot be empty. Please try again.
    GOTO input_folder_name
)

REM Check if the folder already exists
if exist "%root_directory%%folder_name%\" (
    echo Folder '%folder_name%' already exists in '%root_directory%'. Please choose a different name.
    goto input_folder_name
)

REM Create the folder
mkdir "%root_directory%%folder_name%"
if errorlevel 1 (
    echo Failed to create folder '%folder_name%' in '%root_directory%'.
) else (
    echo Folder '%folder_name%' created successfully in '%root_directory%'.
)
REM Pause a few seconds
TIMEOUT /t 3

REM Run the dism command
CLS
dism /online /export-driver /destination:"%root_directory%%folder_name%"
IF NOT errorlevel 1 (
    ECHO dism command completed successfully.
    TIMEOUT /t 60
) ELSE (
    ECHO Error: dism command encountered an error. See the command prompt for details.
pause
)

GOTO EXIT




:RESTORE

REM Perform the directory search and store the results in an array
SET  "count=0"
FOR /d %%D IN ("%root_directory%*") DO (
    SET  /a count+=1
    REM Extract only the directory name without the path and store it in the array
    FOR %%P IN ("%%~nxD") DO (
        SET  "dirname[!count!]=%%~nP"
    )
    SET  "directory[!count!]=%%D"
)

REM Display the folder menu
:FOLDERCHOICE
CLS
ECHO Select a directory:
FOR /l %%i IN (1,1,%count%) DO (
    ECHO %%i. !dirname[%%i]!
)
ECHO 0. Exit

REM Get user input
SET  /p "foldername=Enter the number of your choice: "

REM Process user input
IF "%foldername%"=="0" (
    GOTO EXIT
) ELSE IF "%foldername%" geq "1" IF "%foldername%" leq "%count%" (
    SET  "selected_directory=!directory[%foldername%]!"
    ECHO You selected: !dirname[%foldername%]!
    TIMEOUT /t 3
    REM Run Dism on the selected directory ( !selected_directory! for full path)
    CLS
    REM echo PNPUTIL /add-driver !selected_directory!\*.inf /subdirs /install
    PNPUTIL /add-driver !selected_directory!\*.inf /subdirs /install
    IF NOT errorlevel 1 (
        ECHO Pnputil command completed successfully.
    ) ELSE (
        ECHO Error: Pnputil command encountered an error. See the command prompt for details.
    )
    PAUSE
) ELSE (
    ECHO Invalid choice. Please try again.
    TIMEOUT /t 5
    GOTO FOLDERCHOICE
)

:EXIT
exit /b 0
