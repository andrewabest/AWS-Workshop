# Exercise 1

## Manually provisioning

In this exercise we will be provisioning an EC2 instance by hand to build some familiarity with the web console, and to develop an appreciation for the level of effort involved to launch and configure an instance by hand.

## Goals

* Build familiarity with the AWS Web console
* Develop a healthy appreciation for manual provisioning effort
* Provision a functional web-server by hand, and deploy to it with Octopus

## Instructions

 1. Launch a "Microsoft Windows Server 2012 R2 Base" image-based EC2 instance
 2. Make it a t2.small
 3. Ensure it is on the *Sandbox* VPC, in the *Public A* subnet
 4. Ensure it is assigned a public IP address
 5. Provision a 50 gigabyte *General Purpose* SSD to be used
 6. Tag the instance with {yourinitials}-WebServer
 7. Create a new security group named {yourinitials}-WebServer-SecurityGroup
 8. Given we are going to be using the instance to host a web site, need to remote to it to configure a tentacle, and Octopus needs to talk to it, assign appropriate rules
 9. GO GO GO!
 10. Once launched, remote onto your instance via it's public IP address
 11. Give that this is a base windows image, we will need to add the *Web Server* role to it in Server Management, and ensure under that that we have selected *Application Development > ASP.NET 4.5*
 11. Finally, connect to Octopus (http://52.27.158.189), install a tentacle onto your machine, and add your machine to the CI environment and trigger a deployment
 12. Hit http://localhost - great success!