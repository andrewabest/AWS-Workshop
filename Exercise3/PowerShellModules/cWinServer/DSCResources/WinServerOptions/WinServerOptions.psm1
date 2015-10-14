function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$Culture,

		[System.String]
		$TimeZone
	)

	$returnValue = @{
		Ensure = $Ensure
		Name = $Name
		Culture = $Culture
		Timezone = $Timezone
	}

	return $returnValue;
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$Culture,

		[System.String]
		$TimeZone
	)

	if ($Ensure -eq "Present")
	{
		if ($Culture)
		{
			if ((Get-WinSystemLocale).Name -ne $Culture)
			{
				Write-Verbose "Setting System Locale to $Culture. Will Require reboot to take effect."
				Set-WinSystemLocale -SystemLocale $Culture

				$global:DSCMachineStatus = 1;	
			}
		}

		if (([System.TimeZone]::CurrentTimeZone).StandardName -ne $TimeZone)
		{
			Write-Verbose "Setting System TimeZone to [$TimeZone]"
			& tzutil.exe /s "$TimeZone"
		}
	}
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.String]
		$Culture,

		[System.String]
		$TimeZone
	)

	if ($Ensure -eq "Present")
	{
		if ($Culture)
		{
			if ((Get-WinSystemLocale).Name -ne $Culture)
			{
				Write-Verbose "System Locale is currently $((Get-WinSystemLocale).Name) and should be $Culture"
				return $false;
			}

			Write-Verbose "System Locale and Culture are correct."
		}

		if ($TimeZone)
		{
			if (([System.TimeZone]::CurrentTimeZone).StandardName -ne $TimeZone)
			{
				Write-Verbose "System TimeZone is current:[$(([System.TimeZone]::CurrentTimeZone).StandardName)] and should be:[$TimeZone]"
				return $false;
			}

			Write-Verbose "System TimeZone is correct."
		}
	}
	else
	{
		Write-Verbose "Ignoring checks"
	}
    
    return $true;
}