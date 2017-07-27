﻿Configuration ConfigureWebserver
{
    Import-DscResource -ModuleName cWinServer
	Import-DscResource -ModuleName xWebAdministration
	Import-DscResource -ModuleName xPendingReboot
	Import-DscResource -ModuleName xNetworking

	# Localhost targets the node this script is run on
	Node 'localhost'
	{
		LocalConfigurationManager
		{
			RebootNodeIfNeeded = $True
		}

        WinServerOptions ServerOptions
		{
			Ensure   = "Present"
			Name = "Set timezone and culture"
			Culture  = "en-AU"
			TimeZone = "AUS Eastern Standard Time"
		}

		xPendingReboot AfterServerOptions
        {
			Name = "AfterServerOptions"
            DependsOn = '[WinServerOptions]ServerOptions'
        }

		$windowsFeatures = @(
			"Web-App-Dev",
			"Web-Common-Http",
			"Web-Health",
			"Web-Performance",
			"Web-Security",
			"Web-Scripting-Tools",
			"Web-Mgmt-Service",
			"Web-Mgmt-Console"
		)

		$windowsFeatureDependOn = @();

		foreach ($windowsFeature in $windowsFeatures)
		{
			WindowsFeature "IIS_$windowsFeature"
			{
				Ensure               = "Present"
				Name                 = $windowsFeature
				IncludeAllSubFeature = $true
                DependsOn            = "[xPendingReboot]AfterServerOptions"
			}
            
			$windowsFeatureDependOn += "[WindowsFeature]IIS_$windowsFeature"
		}

		<#
			NOTE: For new players, if you want to discover whether a reboot will be required after a given piece of DSC, search for "$global:DSCMachineStatus = 1" in the resources you have used.
		#>

		xPendingReboot AfterWindowsFeatures
		{
			Name = 'AfterWindowsFeatures'
			DependsOn = $windowsFeatureDependOn
		}

		# Stop & Remove the default website
		xWebsite DefaultSite 
		{
			Ensure          = "Absent"
			Name            = "Default Web Site"
			State           = "Stopped"
			PhysicalPath    = "C:\inetpub\wwwroot"
			DependsOn       = $windowsFeatureDependOn
		}

		# Remove all default Application Pools EXCEPT DEFAULT (will use this for the load balancer health check)
		foreach ($appPool in @("Classic .NET AppPool", ".NET v2.0",
							".NET v2.0 Classic", ".NET v4.5", ".NET v4.5 Classic"))
		{
			xWebAppPool $appPool
			{
				Ensure    = "Absent"
				Name      = $appPool
				DependsOn = ($windowsFeatureDependOn + @("[xWebsite]DefaultSite"))
			}
		}

        # TODO: Use File Resource to add a load-balancer endpoint index.html

        # TODO: Use xWebsite Resource to set up an IIS website at the root of the load-balancer endpoint

        # TODO: Use xFirewall Resource to allow inbound http access on ports 80 and 81
	}
}

ConfigureWebserver

Set-DscLocalConfigurationManager -Path .\ConfigureWebserver -Verbose
Start-DscConfiguration -Path .\ConfigureWebserver -Verbose -Wait -Force
