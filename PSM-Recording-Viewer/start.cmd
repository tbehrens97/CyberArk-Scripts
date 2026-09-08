@echo off
setlocal
cd /d "%~dp0"

set PVWA=https://pvwa.example.com
set PORT=8080
REM SAML (optional). Leave blank to disable. Example IdP-initiated URL:
REM set SAMLURL=https://launcher.myapps.microsoft.com/api/signin/<APP_ID>?tenantId=<TENANT_ID>
set SAMLURL=
set SAMLHELPER=.\bin\getSAMLResponse.exe
set AUTH=CyberArk
set KEEPALIVE=240
set LOCKTIMEOUT=15
set FFMPEG=.\bin\ffmpeg.exe
set PLAYER=
set CACHE=%TEMP%\psmcache
set PRESET=veryfast
set FPS=15
set IDLEMIN=30
set IDLENOISE=-60dB
set IDLEPAD=7

set ARGS=--pvwa %PVWA% --auth %AUTH% --port %PORT%
if not "%SAMLURL%"=="" set ARGS=%ARGS% --saml-url "%SAMLURL%"
if not "%SAMLHELPER%"=="" if exist "%SAMLHELPER%" set ARGS=%ARGS% --saml-helper "%SAMLHELPER%"
if not "%KEEPALIVE%"=="" set ARGS=%ARGS% --keepalive-interval %KEEPALIVE%
if not "%LOCKTIMEOUT%"=="" set ARGS=%ARGS% --lock-timeout %LOCKTIMEOUT%
if "%FFMPEG%"=="" ( set ARGS=%ARGS% --ffmpeg ) else ( if exist "%FFMPEG%" ( set ARGS=%ARGS% --ffmpeg "%FFMPEG%" ) else ( set ARGS=%ARGS% --ffmpeg ) )
if not "%PLAYER%"=="" set ARGS=%ARGS% --player "%PLAYER%"
if not "%CACHE%"=="" set ARGS=%ARGS% --cache "%CACHE%"
if not "%PRESET%"=="" set ARGS=%ARGS% --preset %PRESET%
if not "%FPS%"=="" set ARGS=%ARGS% --fps %FPS%
if not "%IDLEMIN%"=="" set ARGS=%ARGS% --idle-min %IDLEMIN%
if not "%IDLENOISE%"=="" set ARGS=%ARGS% --idle-noise=%IDLENOISE%
if not "%IDLEPAD%"=="" set ARGS=%ARGS% --idle-pad %IDLEPAD%

set PYEXE=.\Python\python.exe
if not exist "%PYEXE%" set PYEXE=python

start "" cmd /c "timeout /t 2 >nul & start """" http://127.0.0.1:%PORT%"
"%PYEXE%" "%~dp0psmviewer.py" %ARGS%
pause

