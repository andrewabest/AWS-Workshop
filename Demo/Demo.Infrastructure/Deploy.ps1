cls

Add-Type -Assembly "System.IO.Compression.FileSystem";
Import-Module AWSPowerShell

############################################################################################################################
#
#	00 - Helper Functions
#
############################################################################################################################

function GenerateConfigFileS3Key($environment, $release, $filename)
{
	$key = $environment + "/" + $release + "/" + $filename
	return $key
}

function CompressDirectoryToArchive($directoryPath, $filePath)
{
	if (Test-Path $filePath)
	{
		Remove-Item $filePath -Force
	}

	[System.IO.Compression.ZipFile]::CreateFromDirectory($directoryPath, $filePath);
}

function EnsureDirectoryExists($directoryPath)
{
	if (-Not (Test-Path $directoryPath))
	{
		New-Item $directoryPath -ItemType Directory
	}
}

############################################################################################################################
#
#	01 - Wrangling Octopus Variables
#
############################################################################################################################

# Create a new variable scope so that we can run this script multiple times
# in a single script console instance without polluting the global scope with
# fake Octopus variables.
& {
	$scriptPath = [System.IO.Path]::GetDirectoryName($myInvocation.PSCommandPath)
	$scriptsPath = "$scriptPath\Scripts"
	EnsureDirectoryExists($scriptsPath)

    if ($OctopusParameters -eq $null)
    {
        Write-Output "Doesn't look like we have any Octopus variables. Using development defaults."

        . .\Parameters.ps1
    }
    else
    {
        Write-Output "Using Octopus-provided variables..."
    }

	# Lower case variables sensitive to casing
	$OctopusParameters['CloudFormationStackName'] = $OctopusParameters['CloudFormationStackName'].ToLowerInvariant()

    Write-Output $OctopusParameters
    Write-Output ""

	# Create a variable-setting PowerShell script and drop it into the Scripts folder
	$octopusVariables = @"

		`$BootstrapParameters = @{}
        `$BootstrapParameters['OctopusServerUrl'] = "$($OctopusParameters['OctopusServerUrl'])"
        `$BootstrapParameters['OctopusApiKey'] = "$($OctopusParameters['OctopusApiKey'])"
        `$BootstrapParameters['OctopusRole'] = "$($OctopusParameters['OctopusRole'])"
		`$BootstrapParameters['Environment'] = "$($OctopusParameters['Octopus.Environment.Name'])"
"@

	$octopusVariables | Out-File -FilePath "$scriptPath\Scripts\Variables.ps1" -Encoding ASCII -Force

	############################################################################################################################
	#
	#	02 - Creating cleanup scripts
	#
	############################################################################################################################

	$cleanupScript = @"
		`
		`# TODO: Remove machines from octopus 
		`
		`# Tear down infrastructure
		`Remove-CFNStack -StackName "$($OctopusParameters['CloudFormationStackName'])" -Force -ProfileName "AWSWorkshop" -Region us-west-2
"@

	$cleanupScript | Out-File -FilePath "$scriptPath\Scripts\Cleanup.ps1" -Encoding ASCII -Force
	
	############################################################################################################################
	#
	#	03 - Push scripts and templates to clouds
	#
	############################################################################################################################

	# Create a directory to store our zipped powershell modules and bootstrapper scripts.
	$tempPath = "$scriptPath\Temp"
	EnsureDirectoryExists($tempPath)

	# Create an S3 bucket to upload our templates and scripts to.
	if (-Not (Get-S3Bucket -BucketName $OctopusParameters['S3BucketName'] -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']))
	{
		Write-Output "Creating S3 bucket..."
		New-S3Bucket -BucketName $OctopusParameters['S3BucketName'] -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']
	}

	# Cleanup scripts
	Write-Output "Uploading cleanup script..."
	$cleanupScriptFullPath = "$scriptPath\Scripts\Cleanup.ps1"
	$cleanupScriptsS3BucketKey = GenerateConfigFileS3Key -environment $OctopusParameters['Octopus.Environment.Name'] -release $OctopusParameters['Octopus.Release.Number'] -filename "Cleanup.ps1"
	Write-S3Object -BucketName: $OctopusParameters['S3BucketName'] -Key $cleanupScriptsS3BucketKey -File $cleanupScriptFullPath -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']
	
	# Powershell modules
	$powerShellModulesFullPath = "$scriptPath\Temp\PowerShellModules.zip"
	CompressDirectoryToArchive -directoryPath "$scriptPath\PowerShellModules" -filePath $powerShellModulesFullPath
	$powerShellModulesS3BucketKey = GenerateConfigFileS3Key -environment $OctopusParameters['Octopus.Environment.Name'] -release $OctopusParameters['Octopus.Release.Number'] -filename "PowerShellModules.zip"
	Write-Output "Uploading powershell modules..."
	Write-S3Object -BucketName: $OctopusParameters['S3BucketName'] -Key $powerShellModulesS3BucketKey -File $powerShellModulesFullPath -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']

	# Bootstrapper scripts
	$scriptsFullPath = "$scriptPath\Temp\Scripts.zip"
	CompressDirectoryToArchive -directoryPath "$scriptPath\Scripts" -filePath $scriptsFullPath
	$scriptsS3BucketKey = GenerateConfigFileS3Key -environment $OctopusParameters['Octopus.Environment.Name'] -release $OctopusParameters['Octopus.Release.Number'] -filename "Scripts.zip"
	Write-Output "Uploading bootstrapper scripts..."
	Write-S3Object -BucketName: $OctopusParameters['S3BucketName'] -Key $scriptsS3BucketKey -File $scriptsFullPath -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']

	# CloudFormation templates
	Write-Output "Uploading CloudFormation templates..."
	$webserverTemplateS3BucketKey = GenerateConfigFileS3Key -environment $OctopusParameters['Octopus.Environment.Name'] -release $OctopusParameters['Octopus.Release.Number'] -filename "Webserver.template"
	Write-S3Object -BucketName: $OctopusParameters['S3BucketName'] -Key $webserverTemplateS3BucketKey -File $scriptPath\Templates\Webserver.template  -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']
	$mainTemplateS3BucketKey = GenerateConfigFileS3Key -environment $OctopusParameters['Octopus.Environment.Name'] -release $OctopusParameters['Octopus.Release.Number'] -filename "Zephyr.template"
	Write-S3Object -BucketName: $OctopusParameters['S3BucketName'] -Key $mainTemplateS3BucketKey -File $scriptPath\Templates\Zephyr.template  -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']

    # Cleanup generated scripts
    Remove-Item "$scriptPath\Scripts\Cleanup.ps1" -Force
    Remove-Item "$scriptPath\Scripts\Variables.ps1" -Force
	Remove-Item "$scriptPath\Temp" -Force -Recurse

	############################################################################################################################
	#
	#	04 - GO GO GO (Create the stack)
	#
	############################################################################################################################

	$powerShellModulesBundleUrl = "https://" + $OctopusParameters['S3BucketName'] + ".s3.amazonaws.com/$powerShellModulesS3BucketKey"
	$bootstrapperScriptBundleUrl = "https://" + $OctopusParameters['S3BucketName'] + ".s3.amazonaws.com/$scriptsS3BucketKey"
	$webserverTemplateUrl = "https://" + $OctopusParameters['S3BucketName'] + ".s3.amazonaws.com/$webserverTemplateS3BucketKey"
	$mainStackTemplateUrl = "https://" + $OctopusParameters['S3BucketName'] + ".s3.amazonaws.com/$mainTemplateS3BucketKey"
	$timestamp = Get-Date -Format u

	$stack = $null
	try 
	{
		$stack = Get-CFNStack -StackName $OctopusParameters['CloudFormationStackName'] -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']
	} 
	catch	
	{ 
	}

	$stackParameters = `
		@(`
		@{ParameterKey="S3BucketName"; ParameterValue=$OctopusParameters['S3BucketName']},`
		@{ParameterKey="VpcId"; ParameterValue=$OctopusParameters['VpcId']},`
		@{ParameterKey="PowerShellModulesBundleUrl"; ParameterValue="$powerShellModulesBundleUrl"},`
		@{ParameterKey="BootstrapperScriptBundleUrl"; ParameterValue="$bootstrapperScriptBundleUrl"},`
		@{ParameterKey="WebserverTemplateUrl"; ParameterValue="$webserverTemplateUrl"},`
		@{ParameterKey="Timestamp"; ParameterValue=$timestamp},`
		@{ParameterKey="Version"; ParameterValue=$OctopusParameters['Octopus.Release.Number']},`
		@{ParameterKey="Environment"; ParameterValue=$OctopusParameters['Octopus.Environment.Name']},`
		@{ParameterKey="KeyPairName"; ParameterValue=$OctopusParameters['KeyPairName']},`
		@{ParameterKey="WebserverImageId"; ParameterValue=$OctopusParameters['WebserverImageId']},`
		@{ParameterKey="WebserverInstanceType"; ParameterValue=$OctopusParameters['WebserverInstanceType']},`
		@{ParameterKey="WebserverSubnetIdAzOne"; ParameterValue=$OctopusParameters['WebserverSubnetIdAzOne']},`
		@{ParameterKey="WebserverSubnetIdAzTwo"; ParameterValue=$OctopusParameters['WebserverSubnetIdAzTwo']},`
		@{ParameterKey="LoadBalancerSubnetIdAzOne"; ParameterValue=$OctopusParameters['LoadBalancerSubnetIdAzOne']},`
		@{ParameterKey="LoadBalancerSubnetIdAzTwo"; ParameterValue=$OctopusParameters['LoadBalancerSubnetIdAzTwo']},`
		@{ParameterKey="ResourcePrefix"; ParameterValue=$OctopusParameters['ResourcePrefix']})

	$stackName = $OctopusParameters['CloudFormationStackName']
	if ($stack -eq $null)
	{
		Write-Output "Creating new CFN stack $stackName"

		New-CFNStack -Capability "CAPABILITY_IAM" -StackName $stackName -TemplateURL $mainStackTemplateUrl -Parameters $stackParameters -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']
	} 
	else 
	{
		Write-Output "Updating existing CFN stack $stackName"

		Update-CFNStack -Capability "CAPABILITY_IAM" -StackName $stackName -TemplateURL $mainStackTemplateUrl -Parameters $stackParameters -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']
	}

	while($true)
	{
		$stack = Get-CFNStack -StackName $stackName -ProfileName "AWSWorkshop" -Region $OctopusParameters['AWSRegion']

		if ($stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::CREATE_COMPLETE -or $stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::UPDATE_COMPLETE)
		{
			Write-Output "Cloud formation succeeded with the following outputs..."
			$stack.Outputs | Format-Table | Write-Output

			# Note: In here, wire up external DNS etc based on stack output parameters

			break;
		}

		if ($stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::CREATE_FAILED -or $stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::ROLLBACK_COMPLETE -or $stack.StackStatus -eq [Amazon.CloudFormation.StackStatus]::ROLLBACK_FAILED)
		{
			Write-Output "Cloud formation failed, abandoning..."

			break;
		}

		Write-Output "Waiting for cloud formation $stackName to finish creation..."

		Start-Sleep -s 10
	}

	Write-Output "fin"
}