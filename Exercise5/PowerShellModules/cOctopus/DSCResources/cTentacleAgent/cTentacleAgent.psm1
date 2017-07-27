$defaultTentacleDownloadUrl = "http://octopusdeploy.com/downloads/latest/OctopusTentacle"
$defaultTentacleDownloadUrl64 = "http://octopusdeploy.com/downloads/latest/OctopusTentacle64"

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
        [ValidateSet("Listen", "Poll")]
        [string]$CommunicationMode = "Listen",
        [string]$ApiKey,
        [string]$DisplayName = "$($env:COMPUTERNAME)_$Name",
        [string]$OctopusServerUrl,
        [string[]]$Environments = "",
        [string[]]$Roles = "",
        [string]$Policy,
        [string[]]$Tenants = "",
        [string[]]$TenantTags = "",
        [string]$DefaultApplicationDirectory,
        [int]$ListenPort=10933,
        [int]$ServerPort=10943,
        [string]$tentacleDownloadUrl = $defaultTentacleDownloadUrl,
        [string]$tentacleDownloadUrl64 = $defaultTentacleDownloadUrl64,
        [ValidateSet("PublicIp", "FQDN", "ComputerName", "Custom")]
        [string]$PublicHostNameConfiguration = "PublicIp",
        [string]$CustomPublicHostName,
        [string]$TentacleHomeDirectory = "$($env:SystemDrive)\Octopus",
        [bool]$RegisterWithServer = $true,
        [string]$OctopusServerThumbprint
    )
    Write-Verbose "Checking if Tentacle is installed"
    $installLocation = (Get-ItemProperty -path "HKLM:\Software\Octopus\Tentacle" -ErrorAction SilentlyContinue).InstallLocation
    $present = ($null -ne $installLocation)
    Write-Verbose "Tentacle present: $present"

    $currentEnsure = if ($present) { "Present" } else { "Absent" }

    $serviceName = (Get-TentacleServiceName $Name)
    Write-Verbose "Checking for Windows Service: $serviceName"
    $serviceInstance = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    $currentState = "Stopped"
    if ($null -ne $serviceInstance)
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

    $originalDownloadUrl = $null
    if (Test-Path "$($env:SystemDrive)\Octopus\Octopus.DSC.installstate") {
        $originalDownloadUrl = (Get-Content -Raw -Path "$($env:SystemDrive)\Octopus\Octopus.DSC.installstate" | ConvertFrom-Json).TentacleDownloadUrl
    }

    return @{
        Name = $Name;
        Ensure = $currentEnsure;
        State = $currentState;
        TentacleDownloadUrl = $originalDownloadUrl;
    };
}

# test a variable has a value (whether its an array or string)
function Test-Value($value) {
    if ($value -eq "") { return $false }
    if ($value.length -eq 0) { return $false }
    if ($value.length -eq 1 -and $value[0].length -eq 0) { return $false }
    return $true
}

function Confirm-RegistrationParameters {
    param (
        [bool]$RegisterWithServer,
        [string[]]$Environments,
        [string[]]$Roles,
        [string]$Policy,
        [string[]]$Tenants,
        [string[]]$TenantTags
    )
    if ($RegisterWithServer) {
        return
    }

    if ((Test-Value($Roles)) -or (Test-Value($Environments)) -or (Test-Value($Tenants)) -or (Test-Value($TenantTags)) -or (Test-Value($Policy))) {
        throw "Invalid configuration requested. " + `
            "You have asked for the Tentacle not to be registered with the server, but still provided a server specific configuration argument (Roles, Environments, Tenants, TenantTags or Policy). " + `
            "Please remove the configuration argument or set 'RegisterWithServer = `$True'."
    }
}


function Confirm-RequestedState() {
    param (
        [ValidateSet("Present", "Absent")]
        [string]$Ensure = "Present",
        [ValidateSet("Started", "Stopped")]
        [string]$State = "Started"
    )
    if ($Ensure -eq "Absent" -and $State -eq "Started")
    {
        throw "Invalid configuration requested. " + `
              "You have asked for the service to not exist, but also be running at the same time. " +`
              "You probably want 'State = `"Stopped`"'."
    }
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
        [ValidateSet("Listen", "Poll")]
        [string]$CommunicationMode = "Listen",
        [string]$ApiKey,
        [string]$OctopusServerUrl,
        [string]$DisplayName = "$($env:COMPUTERNAME)_$Name",
        [string[]]$Environments = "",
        [string[]]$Roles = "",
        [string]$Policy,
        [string[]]$Tenants = "",
        [string[]]$TenantTags = "",
        [string]$DefaultApplicationDirectory = "$($env:SystemDrive)\Applications",
        [int]$ListenPort = 10933,
        [int]$ServerPort = 10943,
        [string]$tentacleDownloadUrl = $defaultTentacleDownloadUrl,
        [string]$tentacleDownloadUrl64 = $defaultTentacleDownloadUrl64,
        [ValidateSet("PublicIp", "FQDN", "ComputerName", "Custom")]
        [string]$PublicHostNameConfiguration = "PublicIp",
        [string]$CustomPublicHostName,
        [string]$TentacleHomeDirectory = "$($env:SystemDrive)\Octopus",
        [bool]$RegisterWithServer = $true,
        [string]$OctopusServerThumbprint
    )
    Confirm-RequestedState $Ensure $State
    Confirm-RegistrationParameters $RegisterWithServer `
        -Environments $Environments `
        -Roles $Roles `
        -Policy $Policy `
        -Tenants $Tenants `
        -TenantTags $TenantTags

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
        if ($RegisterWithServer) {
            Remove-TentacleRegistration -name $Name -apiKey $ApiKey -octopusServerUrl $OctopusServerUrl
        }

        $serviceName = (Get-TentacleServiceName $Name)
        Write-Verbose "Deleting service $serviceName..."
        Invoke-AndAssert { & sc.exe delete $serviceName }

        $otherServices = @(Get-CimInstance win32_service | Where-Object {$_.PathName -like "`"$($env:ProgramFiles)\Octopus Deploy\Tentacle\Tentacle.exe*"})

        if ($otherServices.length -eq 0)
        {
            # Uninstall msi
            Write-Verbose "Uninstalling Tentacle..."
            if (-not (Test-Path "$TentacleHomeDirectory\logs")) { New-Item -type Directory "$TentacleHomeDirectory\logs" }
            $tentaclePath = "$TentacleHomeDirectory\Tentacle.msi"
            $msiLog = "$TentacleHomeDirectory\logs\Tentacle.msi.uninstall.log"
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
        else
        {
            Write-Verbose "Skipping uninstall, as other tentacles still exist:"
            foreach($otherService in $otherServices)
            {
                Write-Verbose " - $($otherService.Name)"
            }
        }
    }
    elseif ($Ensure -eq "Present" -and $currentResource["Ensure"] -eq "Absent")
    {
        Write-Verbose "Installing Tentacle..."
        New-Tentacle -name $Name `
                     -apiKey $ApiKey `
                     -octopusServerUrl $OctopusServerUrl `
                     -port $ListenPort `
                     -displayName $DisplayName `
                     -environments $Environments `
                     -roles $Roles `
                     -policy $Policy `
                     -tenants $Tenants `
                     -tenantTags $TenantTags `
                     -defaultApplicationDirectory $DefaultApplicationDirectory `
                     -tentacleDownloadUrl $tentacleDownloadUrl `
                     -tentacleDownloadUrl64 $tentacleDownloadUrl64 `
                     -communicationMode $CommunicationMode `
                     -serverPort $ServerPort `
                     -publicHostNameConfiguration $PublicHostNameConfiguration `
                     -customPublicHostName $CustomPublicHostName `
                     -tentacleHomeDirectory $TentacleHomeDirectory `
                     -registerWithServer $RegisterWithServer `
                     -octopusServerThumbprint $OctopusServerThumbprint

        Write-Verbose "Tentacle installed!"
    }
    elseif ($Ensure -eq "Present" -and $currentResource["TentacleDownloadUrl"] -ne (Get-TentacleDownloadUrl $tentacleDownloadUrl $tentacleDownloadUrl64))
    {
        Write-Verbose "Upgrading Tentacle..."
        $serviceName = (Get-TentacleServiceName $Name)
        Stop-Service -Name $serviceName
        Install-Tentacle $tentacleDownloadUrl $tentacleDownloadUrl64 $TentacleHomeDirectory
        if ($State -eq "Started") {
            Start-Service $serviceName
        }
        Write-Verbose "Tentacle upgraded!"
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
        [ValidateSet("Listen", "Poll")]
        [string]$CommunicationMode = "Listen",
        [string]$ApiKey,
        [string]$OctopusServerUrl,
        [string]$DisplayName = "$($env:COMPUTERNAME)_$Name",
        [string[]]$Environments = "",
        [string[]]$Roles = "",
        [string]$Policy,
        [string[]]$Tenants = "",
        [string[]]$TenantTags = "",
        [string]$DefaultApplicationDirectory,
        [int]$ListenPort=10933,
        [int]$ServerPort=10943,
        [string]$tentacleDownloadUrl = $defaultTentacleDownloadUrl,
        [string]$tentacleDownloadUrl64 = $defaultTentacleDownloadUrl64,
        [ValidateSet("PublicIp", "FQDN", "ComputerName", "Custom")]
        [string]$PublicHostNameConfiguration = "PublicIp",
        [string]$CustomPublicHostName,
        [string]$TentacleHomeDirectory = "$($env:SystemDrive)\Octopus",
        [bool]$RegisterWithServer = $true,
        [string]$OctopusServerThumbprint
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

    if ($null -ne $currentResource["TentacleDownloadUrl"]) {
        $requestedDownloadUrl = Get-TentacleDownloadUrl $tentacleDownloadUrl $tentacleDownloadUrl64
        $downloadUrlsMatch = $requestedDownloadUrl -eq $currentResource["TentacleDownloadUrl"]
        Write-Verbose "Download Url: $($currentResource["TentacleDownloadUrl"]) vs. $requestedDownloadUrl = $downloadUrlsMatch"
        if (!$downloadUrlsMatch) {
            return $false
        }
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
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12,[System.Net.SecurityProtocolType]::Tls11,[System.Net.SecurityProtocolType]::Tls
    $downloader = new-object System.Net.WebClient
    $downloader.DownloadFile($url, $saveAs)
}

function Invoke-AndAssert {
    param ($block)
    & $block | Write-Verbose
    if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE)
    {
        throw "Command returned exit code $LASTEXITCODE"
    }
}

# After the Tentacle is registered with Octopus, Tentacle listens on a TCP port, and Octopus connects to it. The Octopus server
# needs to know the public IP address to use to connect to this Tentacle instance. Is there a way in Windows Azure in which we can
# know the public IP/host name of the current machine?
function Get-MyPublicIPAddress
{
    Write-Verbose "Getting ***PRIVATE*** IP address"

    try
    {
        $ip = Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/local-ipv4
    }
    catch
    {
        Write-Verbose $_
    }
    return $ip
}

function Install-Tentacle
{
    param (
        [string]$tentacleDownloadUrl,
        [string]$tentacleDownloadUrl64,
        [string]$tentacleHomeDirectory
    )
    Write-Verbose "Beginning Tentacle installation"

    $actualTentacleDownloadUrl = Get-TentacleDownloadUrl $tentacleDownloadUrl $tentacleDownloadUrl64

    mkdir "$tentacleHomeDirectory" -ErrorAction SilentlyContinue

    $tentaclePath = "$tentacleHomeDirectory\Tentacle.msi"
    if ((Test-Path $tentaclePath) -eq $true)
    {
        Remove-Item $tentaclePath -force
    }
    Write-Verbose "Downloading Octopus Tentacle MSI from $actualTentacleDownloadUrl to $tentaclePath"
    Request-File $actualTentacleDownloadUrl $tentaclePath

    Write-Verbose "Installing MSI..."
    if (-not (Test-Path "$TentacleHomeDirectory\logs")) { New-Item -type Directory "$TentacleHomeDirectory\logs" }
    $msiLog = "$TentacleHomeDirectory\logs\Tentacle.msi.log"
    $msiExitCode = (Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $tentaclePath /quiet /l*v $msiLog" -Wait -Passthru).ExitCode
    Write-Verbose "Tentacle MSI installer returned exit code $msiExitCode"
    if ($msiExitCode -ne 0)
    {
        throw "Installation of the Tentacle MSI failed; MSIEXEC exited with code: $msiExitCode. View the log at $msiLog"
    }

    if (-not (Test-Path "$($env:SystemDrive)\Octopus")) { New-Item -type Directory "$($env:SystemDrive)\Octopus" }
    @{ "TentacleDownloadUrl" = $actualTentacleDownloadUrl } | ConvertTo-Json | set-content "$($env:SystemDrive)\Octopus\Octopus.DSC.installstate"

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
        [Parameter(Mandatory=$False)]
        [string[]]$environments = "",
        [Parameter(Mandatory=$False)]
        [string[]]$roles = "",
        [Parameter(Mandatory=$False)]
        [string[]]$tenants = "",
        [Parameter(Mandatory=$False)]
        [string[]]$tenantTags = "",
        [Parameter(Mandatory=$False)]
        [string]$policy,
        [int]$port=10933,
        [string]$displayName,
        [string]$defaultApplicationDirectory,
        [string]$tentacleDownloadUrl,
        [string]$tentacleDownloadUrl64,
        [ValidateSet("Listen", "Poll")]
        [string]$communicationMode = "Listen",
        [int]$serverPort=10943,
        [ValidateSet("PublicIp", "FQDN", "ComputerName", "Custom")]
        [string]$publicHostNameConfiguration = "PublicIp",
        [string]$customPublicHostName,
        [string]$tentacleHomeDirectory = "$($env:SystemDrive)\Octopus",
        [bool]$registerWithServer = $true,
        [Parameter(Mandatory=$False)]
        [string]$octopusServerThumbprint
    )

    if ($port -eq 0)
    {
        $port = 10933
    }

    Install-Tentacle $tentacleDownloadUrl $tentacleDownloadUrl64 $tentacleHomeDirectory

    if ($communicationMode -eq "Listen")
    {
        $windowsFirewall = Get-Service -Name MpsSvc
        if ($windowsFirewall.Status -eq "Running")
        {
            Write-Verbose "Open port $port on Windows Firewall"
            Invoke-AndAssert { & netsh.exe advfirewall firewall add rule protocol=TCP dir=in localport=$port action=allow name="Octopus Tentacle: $Name" }
        }
        else
        {
            Write-Verbose "Windows Firewall Service is not running... skipping firewall rule addition"
        }
    }

    Write-Verbose "Configuring and registering Tentacle"

    Push-Location "${env:ProgramFiles}\Octopus Deploy\Tentacle"

    $tentacleAppDirectory = $DefaultApplicationDirectory
    $tentacleConfigFile = "$tentacleHomeDirectory\$Name\Tentacle.config"
    Write-Verbose "Tentacle configuration set as $tentacleConfigFile"
    Invoke-AndAssert { & .\tentacle.exe create-instance --instance $name --config $tentacleConfigFile --console }
    Invoke-AndAssert { & .\tentacle.exe configure --instance $name --home $tentacleHomeDirectory --console }
    Invoke-AndAssert { & .\tentacle.exe configure --instance $name --app $tentacleAppDirectory --console }
    Invoke-AndAssert { & .\tentacle.exe new-certificate --instance $name --console }

    $registerArguments = @("register-with",
                           "--instance", $name,
                           "--server", $octopusServerUrl,
                           "--name", $displayName,
                           "--apiKey", $apiKey,
                           "--force",
                           "--console")

    if (($null -ne $policy) -and ($policy -ne "")) {
        $registerArguments += @("--policy", $policy)
    }

    if (($null -ne $octopusServerThumbprint) -and ($octopusServerThumbprint -ne "")) {
        Invoke-AndAssert { & .\tentacle.exe configure --instance $name --trust $octopusServerThumbprint --console }
    }

    if ($CommunicationMode -eq "Listen") {
        Invoke-AndAssert { & .\tentacle.exe configure --instance $name --port $port --console }
        $publicHostName = Get-PublicHostName $publicHostNameConfiguration $customPublicHostName
        Write-Verbose "Public host name: $publicHostName"
        $registerArguments += @("--comms-style", "TentaclePassive",
                                "--publicHostName", $publicHostName)
    }
    else {
        Invoke-AndAssert { & .\tentacle.exe configure --instance $name --port $port --noListen "True" --console }
        $registerArguments += @("--comms-style", "TentacleActive",
                                "--server-comms-port", $serverPort)
    }
    Invoke-AndAssert { & .\tentacle.exe service --install --instance $name --console }

    if ($registerWithServer) {
        if ($environments -ne "")
        {
            foreach ($environment in $environments)
            {
                foreach ($e2 in $environment.Split(','))
                {
                    $registerArguments += "--environment"
                    $registerArguments += $e2.Trim()
                }
            }
        }

        if ($roles -ne "")
        {
            foreach ($role in $roles)
            {
                foreach ($r2 in $role.Split(','))
                {
                    $registerArguments += "--role"
                    $registerArguments += $r2.Trim()
                }
            }
        }

        if ($tenants -ne "")
        {
            foreach ($tenant in $tenants)
            {
                foreach ($t2 in $tenant.Split(','))
                {
                    $registerArguments += "--tenant"
                    $registerArguments += $t2.Trim()
                }
            }
        }

        if ($tenantTags -ne "")
        {
            foreach ($tenantTag in $tenantTags)
            {
                foreach ($tt2 in $tenantTag.Split(','))
                {
                    $registerArguments += "--tenanttag"
                    $registerArguments += $tt2.Trim()
                }
            }
        }

        Write-Verbose "Registering with arguments: $registerArguments"
        Invoke-AndAssert { & .\tentacle.exe ($registerArguments) }
    } else {
        Write-Verbose "Skipping registration with server as 'RegisterWithServer' is set to '$registerWithServer'"
    }
    Pop-Location
    Write-Verbose "Tentacle commands complete"
}

function Get-PublicHostName
{
    param (
        [ValidateSet("PublicIp", "FQDN", "ComputerName", "Custom")]
        [string]$publicHostNameConfiguration = "PublicIp",
        [string]$customPublicHostName
    )
    if ($publicHostNameConfiguration -eq "Custom")
    {
        $publicHostName = $customPublicHostName
    }
    elseif ($publicHostNameConfiguration -eq "FQDN")
    {
        $computer = Get-CimInstance win32_computersystem
        $publicHostName = "$($computer.DNSHostName).$($computer.Domain)"
    }
    elseif ($publicHostNameConfiguration -eq "ComputerName")
    {
        $publicHostName = $env:COMPUTERNAME
    }
    else
    {
        $publicHostName = Get-MyPublicIPAddress
    }
    $publicHostName = $publicHostName.Trim()
    return $publicHostName
}

function Get-TentacleDownloadUrl
{
    param (
        [string]$tentacleDownloadUrl,
        [string]$tentacleDownloadUrl64
    )

    if ([IntPtr]::Size -eq 4)
    {
        return $tentacleDownloadUrl
    }
    return $tentacleDownloadUrl64
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
        Push-Location $tentacleDir
        Invoke-AndAssert { & .\tentacle.exe deregister-from --instance "$name" --server $octopusServerUrl --apiKey $apiKey --console }
        Pop-Location
    }
    else
    {
        Write-Verbose "Could not find Tentacle.exe"
    }
}
