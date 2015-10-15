# Exercise 5

## Deployment Magic

In the final exercise, we are going to use some DSC + Octopus magic to [Deploy to Dead Air](http://tech.domain.com.au/2015/04/robot-army-v2-5/). 

## Goals

* Learn how we can automatically deploy our software along with our infrastructure

## Instructions

1. Open .\Exercise5\Parameters.ps1. Update the ResourcePrefix parameter to your initials, and take note of the other parameters provided
2. Open up .\Exercise5\Deploy.ps1
3. With PowerShell, write a file to scriptPath\Scripts\Variables.ps1 containing a HashTable named $BootstrapParameters that contains the values of the following parameters
	* OctopusServerUrl
	* OctopusApiKey
	* OctopusRole
	* Octopus.Environment.Name as 'Environment'
4. The astute observer would notice that this file will be scooped up into our scripts zip that we then download onto our instances during cfn-init
5. Navigate to .\Exercise5\PowerShellModules\cOctopus\DSCResources\cTentacleAgent\cTentacleAgent.psm1 and open it up in PowerShell ISE
6. Follow through **Set-TargetResource** and see how it does its thing
7. Follow through to **Request-CurrentPackageVersions** and see how it behaves. See if you can guess what behaviour this function elicits
8. Open up .\Exercise5\Scripts\ConfigureWebserver.ps1
9. At the top of the file, determine the execution location using

    [System.IO.Path]::GetDirectoryName($PSScriptRoot)
10. This will give us the root execution location - c:\cfn. Now we can dot-source our variables.ps1 file that will be downloaded onto the machine
11. Now that we have our $BootstrapParameters collection in scope, we can use the values in it to add a [cTentacleAgent resource](https://github.com/OctopusDeploy/OctopusDSC) to the end of our DSC configuration
12. Return to .\Exercise5\Deploy.ps1 and F5!
13. Monitor your stack's creation, and once your instances are available, remote in and take a look in the cfn-init log along with the DSC logs and ensure the operation was successful
14. If all went well, your machines should pop up in Octopus, and have a deployment triggered for themselves (one deployment per machine)
15. Hit your load balancer URL returned by the script! Wow! Such automated. Much website

