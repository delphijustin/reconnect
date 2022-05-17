@echo off
::echo on
::remove the first "::" from "::echo on" line to debug this batch file
if "%1"=="/TCP" goto TCPPorts
if "%1"=="fail" goto noIPAPI
if "%2 %3 %4"==":Secure Internet LLC:" goto vpninuse
if "%2"=="VOXILITY-DE" goto vpninuse
if "%2"=="VOXILITY" goto vpninuse
::The if command above this line checks the ISP name to see if they both
::equal NOTE THE NAME MUST BE TYPED EXACTLY THE SAME.
echo Attempting to reconnect...
if "%1 %2"==":DOWNLOAD ERROR" goto neterror
:vpndial
echo Reconnectin
::VPN Reconnecting commnads go here...
call d:\purevpn.bat
::Remove call d:\purevpn.bat if your not delphijustin
exit /b 0
:noIPAPI
::put commands here for ip-api.com specific errors
exit /b 0
:TCPPorts
shift
if "%1"=="" goto TCPDone
if "%1"=="OK" exit /b 0
::Enter commands here for each bad port
::each port goes through the %1 variable
echo [%date% - %time%] - %1>>BadTCP.log
goto TCPPorts
:TCPDone
::enter commands here to execute after all ports are finshed
::by default the neterror commands are executed next
:neterror
::No networking commands goo here
goto vpndial
:vpninuse
::Commands entered here will execcute when ISP is "Secure Internet LLC"
