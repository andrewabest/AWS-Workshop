@echo off

IF '%~1' == '' ECHO "Missing 'AccessKey' arg"
IF '%~1' == '' GOTO ERROR

IF '%~2' == '' ECHO "Missing 'SecretKey' arg"
IF '%~2' == '' GOTO ERROR

powershell.exe -ExecutionPolicy Bypass -Command "Set-AWSCredentials -AccessKey %~1 -SecretKey %~2 -StoreAs AWSWorkshop"

exit /b 0

	goto end

:error

	echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	echo !!! Stopping due to error    !!!
	echo !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

	exit /b 1

	goto end

:end
	exit /b