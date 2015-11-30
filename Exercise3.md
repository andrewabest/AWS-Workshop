# Exercise 3

## PowerShell DSC authoring

In this exercise we will build out a sample DSC template and apply it to our CloudFormation-created web servers that we created in [Exercise 2](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise2.md).

We are going to configure a website to act as a basic load balancer endpoint that our server's IIS can serve up when requested over port 81 - a static index.html file will suffice. 

## Goals

* Use DSC resources to add a load balancer endpoint and firewall exceptions to the supplied DSC template
* See what happens when a configuration fails to compile, and know how to 'fail fast'
* See the output of the Local Configuration Manager when it applies a configuration
* Discover how to diagnose errors that occur when applying DSC configurations
* Configure a Windows server with DSC

## Instructions

1. Remote into your EC2 instance that you created with CloudFormation in [Exercise 2](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise2.md).
2. Copy the contents of .\Exercise3 onto the instance
3. Jump into PowerShell ISE on your instance and allow us to utilize our unsigned DSC resources by executing the following

   > Set-ExecutionPolicy Bypass

4. Open .\Exercise3\PowerShellModules, and copy all of the folders therein over to 

	> C:\Program Files\WindowsPowerShell\Modules
5. Open .\Exercise3\DSC_Diagnostics.md and read it. Enable low level logging on your instance, and have a play with the Get and Trace cmdlets mentioned
6. Open .\Exercise3\ConfigureWebserver.ps1 - this is our DSC configuration. Take a look at its structure. Look at what it is already doing
7. Complete the [File](https://msdn.microsoft.com/en-us/PowerShell/DSC/fileResource) resource TODO
8. Complete the [xWebsite](https://github.com/PowerShell/xWebAdministration#xwebsite) resource TODO
9. Complete the [xFirewall](https://github.com/PowerShell/xNetworking#xfirewall) resource TODO
10. F5 your configuration. The machine will need to reboot a couple of times - you can see where by looking for the **xPendingReboot** resource usage
11. Monitor the EC2 console in AWS for your machine to come back online - once it is, remote back into it
12. Open the DSC_Diagnostics.md guide again and use the instructions to see what operations were executed, if they were successful or not, and what diagnostic information you are provided with
13. If there were errors, troubleshoot what they were. Pair up, rubber duck, whatever works! Once you think you have fixed the errors in your configuration again, F5 it again!
14. Rinse and repeat until you have succesfully configured your server

### Gotchas

If you want to run the configuration multiple times, you will need to remove the previously generated MOF before regenerating a new one, or you will get a reasonably undecipherable error
