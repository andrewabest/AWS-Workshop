function Get-TargetResource
{
    [OutputType([Hashtable])]
    param (
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started",
        
        [string]$ApiKey,
        [string]$OctopusServerUrl,
        [string[]]$Environments,
        [string[]]$Roles,
        [string]$DefaultApplicationDirectory,
        [int]$ListenPort
    )

    Write-Verbose "Checking if Tentacle is installed"
    $installLocation = (get-itemproperty -path "HKLM:\Software\Octopus\Tentacle" -ErrorAction SilentlyContinue).InstallLocation
    $present = ($installLocation -ne $null)
    Write-Verbose "Tentacle present: $present"
    
    $currentEnsure = if ($present) { "Present" } else { "Absent" }

    $serviceName = (Get-TentacleServiceName $Name)
    Write-Verbose "Checking for Windows Service: $serviceName"
    $serviceInstance = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    $currentState = "Stopped"
    if ($serviceInstance -ne $null) 
    {
        Write-Verbose "Windows service: $($serviceInstance.Status)"
        if ($serviceInstance.Status -eq "Running") 
        {
            $currentState = "Started"
        }
        
        if ($currentEnsure -eq "Absent") 
        {
            Write-Verbose "Since the Windows Service is still installed, the service is present"
            $currentEnsure = "Present"
        }
    } 
    else 
    {
        Write-Verbose "Windows service: Not installed"
        $currentEnsure = "Absent"
    }

    return @{
        Name = $Name; 
        Ensure = $currentEnsure;
        State = $currentState;
    };
}

function Set-TargetResource 
{
    param (       
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started",
        
        [string]$ApiKey,
        [string]$OctopusServerUrl,
        [string[]]$Environments,
        [string[]]$Roles,
        [string]$DefaultApplicationDirectory = "$($env:SystemDrive)\Applications",
        [int]$ListenPort = 10933
    )

    if ($Ensure -eq "Absent" -and $State -eq "Started") 
    {
        throw "Invalid configuration: service cannot be both 'Absent' and 'Started'"
    }

    $currentResource = (Get-TargetResource -Name $Name)

    Write-Verbose "Configuring Tentacle..."

    if ($State -eq "Stopped" -and $currentResource["State"] -eq "Started") 
    {
        $serviceName = (Get-TentacleServiceName $Name)
        Write-Verbose "Stopping $serviceName"
        Stop-Service -Name $serviceName -Force
    }

    if ($Ensure -eq "Absent" -and $currentResource["Ensure"] -eq "Present")
    {
        Remove-TentacleRegistration -name $Name -apiKey $ApiKey -octopusServerUrl $OctopusServerUrl
        
        $serviceName = (Get-TentacleServiceName $Name)
        Write-Verbose "Deleting service $serviceName..."
        Invoke-AndAssert { & sc.exe delete $serviceName }
        
        # Uninstall msi
        Write-Verbose "Uninstalling Tentacle..."
        $tentaclePath = "$($env:SystemDrive)\Octopus\Tentacle.msi"
        $msiLog = "$($env:SystemDrive)\Octopus\Tentacle.msi.uninstall.log"
        if (test-path $tentaclePath)
        {
            $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $tentaclePath /quiet /l*v $msiLog" -Wait -Passthru).ExitCode
            Write-Verbose "Tentacle MSI installer returned exit code $msiExitCode"
            if ($msiExitCode -ne 0) 
            {
                throw "Removal of Tentacle failed, MSIEXEC exited with code: $msiExitCode. View the log at $msiLog"
            }
        }
        else 
        {
            throw "Tentacle cannot be removed, because the MSI could not be found."
        }
    } 
    elseif ($Ensure -eq "Present" -and $currentResource["Ensure"] -eq "Absent") 
    {
        Write-Verbose "Installing Tentacle..."
        New-Tentacle -name $Name -apiKey $ApiKey -octopusServerUrl $OctopusServerUrl -port $ListenPort -environments $Environments -roles $Roles -DefaultApplicationDirectory $DefaultApplicationDirectory
        Write-Verbose "Tentacle installed!"
    }

    if ($State -eq "Started" -and $currentResource["State"] -eq "Stopped") 
    {
        $serviceName = (Get-TentacleServiceName $Name)
        Write-Verbose "Starting $serviceName"
        Start-Service -Name $serviceName
    }

    Write-Verbose "Finished"
}

function Test-TargetResource 
{
    param (       
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started",
        
        [string]$ApiKey,
        [string]$OctopusServerUrl,
        [string[]]$Environments,
        [string[]]$Roles,
        [string]$DefaultApplicationDirectory,
        [int]$ListenPort
    )
 
    $currentResource = (Get-TargetResource -Name $Name)

    $ensureMatch = $currentResource["Ensure"] -eq $Ensure
    Write-Verbose "Ensure: $($currentResource["Ensure"]) vs. $Ensure = $ensureMatch"
    if (!$ensureMatch) 
    {
        return $false
    }
    
    $stateMatch = $currentResource["State"] -eq $State
    Write-Verbose "State: $($currentResource["State"]) vs. $State = $stateMatch"
    if (!$stateMatch) 
    {
        return $false
    }

    return $true
}

function Get-TentacleServiceName 
{
    param ( [string]$instanceName )

    if ($instanceName -eq "Tentacle") 
    {
        return "OctopusDeploy Tentacle"
    } 
    else 
    {
        return "OctopusDeploy Tentacle: $instanceName"
    }
}

function Request-File 
{
    param (
        [string]$url,
        [string]$saveAs
    )
 
    Write-Verbose "Downloading $url to $saveAs"
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $saveAs)
}

function Invoke-AndAssert {
    param ($block) 
  
    & $block | Write-Verbose
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) 
    {
        throw "Command returned exit code $LASTEXITCODE"
    }
}

# After the Tentacle is registered with Octopus, Tentacle listens on a TCP port, and Octopus connects to it. The Octopus server
# needs to know the public IP address to use to connect to this Tentacle instance. Is there a way in Windows Azure in which we can 
# know the public IP/host name of the current machine?

function Get-MyPublicIPAddress
{
    Write-Verbose "Getting public IP address"
    $downloader = new-object System.Net.WebClient
    $ip = ""
	$attempts = 0

	while ([string]::IsNullOrWhiteSpace($ip) -and $attempts -lt 5)
	{
		$ip = $downloader.DownloadString("https://api.ipify.org/")

        if ([string]::IsNullOrWhiteSpace($ip))
        {
            $attempts++
		    Start-Sleep -s 10
        }
	}

    return $ip
}
  
function New-Tentacle 
{
    param (
        [Parameter(Mandatory=$True)]
        [string]$name,
        [Parameter(Mandatory=$True)]
        [string]$apiKey,
        [Parameter(Mandatory=$True)]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$True)]
        [string[]]$environments,
        [Parameter(Mandatory=$True)]
        [string[]]$roles,
        [int] $port,
        [string]$DefaultApplicationDirectory
    )
 
    if ($port -eq 0) 
    {
        $port = 10933
    }

    Write-Verbose "Beginning Tentacle installation" 
  
    $tentacleDownloadUrl = "http://octopusdeploy.com/downloads/latest/OctopusTentacle64"
    if ([IntPtr]::Size -eq 4) 
    {
        $tentacleDownloadUrl = "http://octopusdeploy.com/downloads/latest/OctopusTentacle"
    }

    mkdir "$($env:SystemDrive)\Octopus" -ErrorAction SilentlyContinue

    $tentaclePath = "$($env:SystemDrive)\Octopus\Tentacle.msi"
    if ((test-path $tentaclePath) -ne $true) 
    {
        Write-Verbose "Downloading latest Octopus Tentacle MSI from $tentacleDownloadUrl to $tentaclePath"
        Request-File $tentacleDownloadUrl $tentaclePath
    }
  
    Write-Verbose "Installing MSI..."
    $msiLog = "$($env:SystemDrive)\Octopus\Tentacle.msi.log"
    $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $tentaclePath /quiet /l*v $msiLog" -Wait -Passthru).ExitCode
    Write-Verbose "Tentacle MSI installer returned exit code $msiExitCode"
    if ($msiExitCode -ne 0) 
    {
        throw "Installation of the Tentacle MSI failed; MSIEXEC exited with code: $msiExitCode. View the log at $msiLog"
    }
 
    Write-Verbose "Open port $port on Windows Firewall"
    Invoke-AndAssert { & netsh.exe advfirewall firewall add rule protocol=TCP dir=in localport=$port action=allow name="Octopus Tentacle: $Name" }
    
	<#
    $ipAddress = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/local-ipv4
    $ipAddress = $ipAddress.Trim()
    Write-Verbose "Private IP address: $ipAddress"
	#>

	$ipAddress = Get-MyPublicIPAddress
    $ipAddress = $ipAddress.Trim()
    Write-Verbose "Public IP address: $ipAddress"

    Write-Verbose "Configuring and registering Tentacle"
  
    pushd "${env:ProgramFiles}\Octopus Deploy\Tentacle"
 
    $tentacleHomeDirectory = "$($env:SystemDrive)\Octopus"
    $tentacleAppDirectory = $DefaultApplicationDirectory
    $tentacleConfigFile = "$($env:SystemDrive)\Octopus\$Name\Tentacle.config"
    Invoke-AndAssert { & .\tentacle.exe create-instance --instance $name --config $tentacleConfigFile --console }
    Invoke-AndAssert { & .\tentacle.exe configure --instance $name --home $tentacleHomeDirectory --console }
    Invoke-AndAssert { & .\tentacle.exe configure --instance $name --app $tentacleAppDirectory --console }
    Invoke-AndAssert { & .\tentacle.exe configure --instance $name --port $port --console }
    Invoke-AndAssert { & .\tentacle.exe new-certificate --instance $name --console }
    Invoke-AndAssert { & .\tentacle.exe service --install --instance $name --console }

    $registerArguments = @("register-with", "--instance", $name, "--server", $octopusServerUrl, "--name", $env:COMPUTERNAME, "--publicHostName", $ipAddress, "--apiKey", $apiKey, "--comms-style", "TentaclePassive", "--force", "--console")

    foreach ($environment in $environments) 
    {
        foreach ($e2 in $environment.Split(',')) 
        {
            $registerArguments += "--environment"
            $registerArguments += $e2.Trim()
        }
    }
    foreach ($role in $roles) 
    {
        foreach ($r2 in $role.Split(',')) 
        {
            $registerArguments += "--role"
            $registerArguments += $r2.Trim()
        }
    }

    Write-Verbose "Registering with arguments: $registerArguments"
    Invoke-AndAssert { & .\tentacle.exe ($registerArguments) } -ErrorAction SilentlyContinue

    popd
	Write-Verbose "Tentacle registration complete"

	Request-CurrentPackageVersions -name $env:COMPUTERNAME -apiKey $apiKey -octopusServerUrl $octopusServerUrl -environments $environments -roles $roles
}


function Remove-TentacleRegistration 
{
    param (
        [Parameter(Mandatory=$True)]
        [string]$name,
        [Parameter(Mandatory=$True)]
        [string]$apiKey,
        [Parameter(Mandatory=$True)]
        [string]$octopusServerUrl
    )
  
    $tentacleDir = "${env:ProgramFiles}\Octopus Deploy\Tentacle"
    if ((test-path $tentacleDir) -and (test-path "$tentacleDir\tentacle.exe")) 
    {
        Write-Verbose "Beginning Tentacle deregistration" 
        Write-Verbose "Tentacle commands complete"
        pushd $tentacleDir
        Invoke-AndAssert { & .\tentacle.exe deregister-from --instance "$name" --server $octopusServerUrl --apiKey $apiKey --console }
        popd
    }
    else 
    {
        Write-Verbose "Could not find Tentacle.exe"
    }
}

function Request-CurrentPackageVersions
{
 param (
        [Parameter(Mandatory=$True)]
        [string]$name,
        [Parameter(Mandatory=$True)]
        [string]$apiKey,
        [Parameter(Mandatory=$True)]
        [string]$octopusServerUrl,
        [Parameter(Mandatory=$True)]
        [string[]]$environments,
        [Parameter(Mandatory=$True)]
        [string[]]$roles
    )

	Write-Verbose "Requesting deployments for releases that should be on this tentacle"

	$machine = Get-OctopusMachine -machineName $name -octopusServerUrl $octopusServerUrl -apiKey $apiKey
    if (-Not $machine){
        write-error "Could not find octopus machine $name"
        return
    }
	$octopusEnvironments =  Invoke-RestMethod -Method Get -Uri "$octopusServerUrl/api/environments/all" -Header @{"X-Octopus-ApiKey"=$apiKey} -Verbose
    foreach ($environment in $environments)
    {
		$octopusEnvironment = $octopusEnvironments | Where-Object { $PSItem.Name -eq $environment} | select Id -First 1
		$octopusDashboard = Invoke-RestMethod -Method Get -Uri "$octopusServerUrl/api/dashboard" -Header @{"X-Octopus-ApiKey"=$apiKey} -Verbose
		$itemsToDeploy = $octopusDashboard.Items | ? {$PSItem.EnvironmentId -eq $octopusenvironment.Id}
		foreach ($item in $itemsToDeploy)
		{
			$body = @{}
			$body.Comments = "Deployment triggered by Octopus DSC"
			$body.EnvironmentId = $item.EnvironmentId
			$body.ReleaseId = $item.ReleaseId
			$body.SpecificMachineIds = @($machine.Id)
			$json = $body | ConvertTo-Json
			Write-Verbose "Requesting deployment: $json"
			Invoke-RestMethod -Method Post -Uri "$octopusServerUrl/api/deployments" -body $json -Header @{"X-Octopus-ApiKey"=$apiKey} -Verbose
		}
	}
}

function Get-OctopusMachine
{
	param (
        [Parameter(Mandatory=$True)]
        [string]$machineName,
        [Parameter(Mandatory=$True)]
        [string]$apiKey,
        [Parameter(Mandatory=$True)]
        [string]$octopusServerUrl
	)

	$skip = 0
	while ($true)
	{
		$machines = Invoke-RestMethod -Method Get -Uri "$octopusServerUrl/api/machines/all?skip=$skip" -Header @{"X-Octopus-ApiKey"=$apiKey} -Verbose

       if ($machines.Length -eq 0)
		{
			return $null
		}

		foreach ($machine in $machines)
		{
			if ($machine.Name -eq $machineName)
			{
				return $machine
			}
		}

        if ($machines.Count -lt 30)
        {
            return $null
        }
		$skip = $skip + 30
	}
}
