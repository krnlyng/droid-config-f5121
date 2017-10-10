@echo off

:: This is simple windows flashing script for Sony Xperia X device
:: This script is using fastboot to flash which differs from the factory method.

set tmpflashfile=tmpfile.txt
set emmawebsite=https://developer.sonymobile.com/open-devices/flash-tool/how-to-download-and-install-the-flash-tool/
set unlockwebsite=https://developer.sonymobile.com/unlockbootloader/
set oemblobwebsite=https://developer.sonymobile.com/downloads/software-binaries/software-binaries-for-aosp-marshmallow-android-6-0-1-kernel-3-10-loire/

echo(
echo This is a Windows flashing script for Sony Xperia X device.
echo(
echo Power on the device in fastboot mode, by doing the following:
echo 1. Turn off your Xperia.
echo 2. Connect one end of a USB cable to your PC.
echo 3. While holding the volume up button pressed, connect the other end of
echo    the USB cable to your Xperia.
echo 4. After this you should see the blue LED lit on Xperia, and it will be
echo    ready for flashing
echo(
pause
call :sleep 3

:: Bus 002 Device 025: ID 0fce:0dde Sony Ericsson Mobile Communications AB Xperia Mini Pro Bootloader
set vendorid=0x0fce
set fastbootcmd=fastboot.exe -i %vendorid%

echo Searching a device with vendor id '%vendorid%'..

:: Ensure that we are flashing right device
:: F5121 - Xperia X
:: F5122 - Xperia X Dual SIM
:: F5321 - Xperia X Compact
@call :getvar product
findstr /R /C:"product: F512[12]" %tmpflashfile% >NUL 2>NUL
if not errorlevel 1 GOTO no_error_product

echo(
echo The DEVICE this flashing script is meant for WAS NOT FOUND!
echo You might be missing the required windows fastboot drivers for your device.
echo Go to the Windows Device Manager and update the fastboot driver for the
echo device.
echo(
pause
exit /b 1

:no_error_product

:: Check that device has been unlocked
@call :getvar secure
findstr /R /C:"secure: no" %tmpflashfile% >NUL 2>NUL
if not errorlevel 1 GOTO no_error_unlock
echo(
echo This device has not been unlocked for the flashing. Please follow the
echo instructions how to unlock your device at the following webpage:
echo %unlockwebsite%
echo(
echo Press enter to open browser with the webpage.
echo(
pause
start "" %unlockwebsite%
exit /b 1

:no_error_unlock

:: Verify that the Sony release on the phone is new enough.
@call :getvar version-baseband

:: Take from 1300-4911_34.0.A.2.292 the first number set, e.g., 34.0
for /f "tokens=2 delims=_" %%i in ('type %tmpflashfile%') do @set version1=%%i
for /f "tokens=1-2 delims=." %%a in ('echo %version1%') do @set version2=%%a.%%b

:: We only support devices that have been flashed at least with version 34.3 of the Sony Android delivery
if %version2% LSS 34.3 (
echo(
echo The Sony Android version on your device is too old, please update your
echo device with instructions provided at the following webpage:
echo %emmawebsite%
echo(
echo Press enter to open the browser with the webpage.
echo(
pause
start "" %emmawebsite%
exit /b 1
)

del %tmpflashfile% >NUL 2>NUL
setlocal EnableDelayedExpansion

:: Find the blob image. Make sure there's only one.
for /r %%f in (*_loire.img) do (
if not defined blobfilename (
:: Take only the filename and strip out the path which otherwise is there.
:: This is to make sure that we do not face issues later with e.g. spaces in the path etc.
set blobfilename=%%~nxf
) else (
echo(
echo More than one Sony Vendor image was found in this directory.
echo Please remove any additional files (*_loire.img).
echo(
exit /b 1
)
)

:: Bail out if we don't have a blob image
if not defined blobfilename (
echo(
echo The Sony Vendor partition image was not found in the current
echo directory. Please download it from %oemblobwebsite%
echo and unzip it into this directory.
echo(
echo Press enter to open the browser with the webpage.
echo(
pause
start "" %oemblobwebsite%
exit /b 1
)

:: We want to print the fastboot commands so user can see what actually
:: happens when flashing is done.
@echo on

@call :fastboot flash boot hybris-boot.img
@call :fastboot flash system fimage.img001
@call :fastboot flash userdata sailfish.img001
@call :fastboot flash oem %blobfilename%

:: NOTE: Do not reboot here as the battery might not be in the device
:: and in such situation we should not reboot the device.
@echo(
@echo Flashing completed.
@echo(
@echo Remove the USB cable and bootup the device by pressing powerkey.
@echo(
@pause

@exit /b 0

:: Function to sleep X seconds
:sleep
:: @echo "Waiting %*s.."
ping 127.0.0.1 -n %* >NUL
@exit /b 0

:getvar
del %tmpflashfile% >NUL 2>NUL

start /b cmd /c %fastbootcmd% getvar %* 2^>^&1 ^| find "%*:" ^> %tmpflashfile%
call :sleep 3
:: In case the device is not online, fastboot will just hang forever thus
:: kill it here so the script ends at some point.
taskkill /im fastboot.exe /f >NUL 2>NUL
@exit /b 0

:md5sum
@set md5sumold=
:: Before flashing calculate md5sum to ensure file is not corrupted, so for each line in md5.lst do
@for /f %%i in ('findstr %~1 md5.lst') do @set md5sumold=%%i
:: Some files e.g. oem partition image is not part of md5.lst so skip checking md5sum for that file
@if [%md5sumold%] == [] goto :skip_md5sum
:: We want to take the second line of output from CertUtil, if you know better way let me know :)
:: delims= is needed for this to work on windows 8
@for /f "skip=1 tokens=1 delims=" %%i in ('CertUtil -hashfile "%~1" MD5') do @set md5sumnew=%%i && goto :file_break
:file_break
:: Drop all spaces from the md5sumnew as the format provided by CertUtil is two chars space two chars..
@set md5sumnew=%md5sumnew: =%
:: Drop everything after the first space in md5sumold
@set "md5sumold=%md5sumold: ="&rem %
@IF NOT "%md5sumnew%" == "%md5sumold%" (
  @echo(
  @echo MD5SUM '%md5sumnew%' of file %~1 does not match to md5.lst '%md5sumold%'.
  @call :exitflashfail
)
@echo MD5SUM '%md5sumnew%' match for %~1.
:skip_md5sum
@exit /b 0

:: Function to call fastboot command with error checking
:fastboot
:: When flashing check md5sum of files
@IF "%~1" == "flash" (
  @call :md5sum %~3
)
%fastbootcmd% %*
@IF "%ERRORLEVEL%" == "1" (
  @echo(
  @echo ERROR: Failed to execute '%fastbootcmd% %*'.
  @call :exitflashfail
)
@exit /b 0

:exitflashfail
@echo(
@echo FLASHING FAILED!
@echo(
@echo Please go to https://together.jolla.com/ and ask for guidance.
@echo(
@pause
@exit 1
@exit /b 0
