cls

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

############################################################################################################################
#
#	01 - Wrangling Octopus Variables
#
############################################################################################################################

# Create a new variable scope so that we can run this script multiple times
# in a single script console instance without polluting the global scope with
# fake variables.
& {
    $scriptPath = [System.IO.Path]::GetDirectoryName($myInvocation.PSCommandPath)

    . .\Parameters.ps1

	# Lower case variables sensitive to casing
	$Parameters['CloudFormationStackName'] = $Parameters['CloudFormationStackName'].ToLowerInvariant()
    $Parameters['S3BucketName'] = $Parameters['S3BucketName'].ToLowerInvariant()

    Write-Output $Parameters
    Write-Output ""
	
	############################################################################################################################
	#
	#	02 - Push templates to clouds
	#
	############################################################################################################################

	# Create an S3 bucket to upload our templates and scripts to.
	if (-Not (Get-S3Bucket -BucketName $Parameters['S3BucketName'] -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"))
	{
		Write-Output "Creating S3 bucket..."
		New-S3Bucket -BucketName $Parameters['S3BucketName'] -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"
	}

	# CloudFormation templates
	Write-Output "Uploading CloudFormation templates..."
	$webserverTemplateS3BucketKey = GenerateConfigFileS3Key -environment $Parameters['Environment'] -release $Parameters['Version'] -filename "Webserver.template"
	Write-S3Object -BucketName: $Parameters['S3BucketName'] -Key $webserverTemplateS3BucketKey -File $scriptPath\Templates\Webserver.template -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"
	
	############################################################################################################################
	#
	#	03 - GO GO GO (Create the stack)
	#
	############################################################################################################################

	$webserverTemplateUrl = "https://" + $Parameters['S3BucketName'] + ".s3.amazonaws.com/$webserverTemplateS3BucketKey"
	$timestamp = Get-Date -Format u

	$stack = $null
	try 
	{
		$stack = Get-CFNStack -StackName $Parameters['CloudFormationStackName'] -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"
	} 
	catch	
	{ 
	}

	$stackParameters = `
		@(`
		@{ParameterKey="VpcId"; ParameterValue=$Parameters['VpcId']},`
		@{ParameterKey="Version"; ParameterValue=$Parameters['Version']},`
		@{ParameterKey="Environment"; ParameterValue=$Parameters['Environment']},`
		@{ParameterKey="KeyPairName"; ParameterValue=$Parameters['KeyPairName']},`
		@{ParameterKey="WebserverImageId"; ParameterValue=$Parameters['WebserverImageId']},`
		@{ParameterKey="WebserverInstanceType"; ParameterValue=$Parameters['WebserverInstanceType']},`
		@{ParameterKey="WebserverSubnetId"; ParameterValue=$Parameters['WebserverSubnetId']},`
		@{ParameterKey="ResourcePrefix"; ParameterValue=$Parameters['ResourcePrefix']})

	$stackName = $Parameters['CloudFormationStackName']
	if ($stack -eq $null)
	{
		Write-Output "Creating new CFN stack $stackName"

		New-CFNStack -Capability "CAPABILITY_IAM" -StackName $stackName -TemplateURL $webserverTemplateUrl -Parameters $stackParameters -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"
	} 
	else 
	{
		Write-Output "Updating existing CFN stack $stackName"

		Update-CFNStack -Capability "CAPABILITY_IAM" -StackName $stackName -TemplateURL $webserverTemplateUrl -Parameters $stackParameters -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"
	}

	while($true)
	{
		$stack = Get-CFNStack -StackName $stackName -Region $Parameters['AWSRegion'] -ProfileName "AWSWorkshop"

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