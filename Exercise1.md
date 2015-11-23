# Exercise 1

## Manually provisioning

In this exercise we will be provisioning an EC2 instance by hand to build some familiarity with the web console, and to develop an appreciation for the level of effort involved to launch and configure an instance by hand.

## Goals

* Build familiarity with the AWS Web console
* Develop a healthy appreciation for manual provisioning effort
* Provision a functional web-server by hand, and deploy to it with Octopus

## Instructions

 1. Open the EC2 console within the AWS web console
 2. Launch a "Microsoft Windows Server 2012 R2 Base" image-based EC2 instance
 3. Make it a t2.small
 4. Ensure it is on the *Sandbox* VPC, in the *Public A* subnet
 5. Ensure it is assigned a public IP address
 6. Provision a 50 gigabyte *General Purpose* SSD to be used
 7. Tag the instance with {yourinitials}-WebServer
 8. Create a new security group named {yourinitials}-WebServer-SecurityGroup
 9. Given we are going to be using the instance to host a web site, need to remote to it to configure a tentacle, and Octopus needs to talk to it, assign inbound access rules for ports 80, 3389 and 10933
 10. GO GO GO! (Click Launch)
 11. You will be prompted for a key pair that will be used to generate the instance's administrator password. Select the AwsDayKeyPair
 12. Once launched, remote onto your instance via it's public IP address - to retrieve the password for your instance, select it in the console and click 'Connect', locate the .pem file for the AwsDayKeyPair and click 'Decrypt Password'
 13. Give that this is a base windows image, we will need to add the *Web Server* role to it in Server Management, and ensure under that that we have selected *Application Development > ASP.NET 4.5*
 14. Finally, connect to Octopus (address and credentials are be provided), install a tentacle onto your machine, add your machine to the CI environment and trigger a deployment
 15. Hit http://localhost - great success!
