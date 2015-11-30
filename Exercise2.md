# Exercise 2

## Cloud Formation templating

In this exercise we will build a cloud formation template to provision the security group and EC2 instance pair that we manually created in [Exercise 1](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise1.md)

## Goals

* Gain exposure to AWS powershell API
* Get hands dirty building a CloudFormation template
* Launch a security group and EC2 instance via powershell - Infrastructure as code!

## Prior to starting

To complete this exercise you'll need to add an appropriate set of credentials to your [SDK Credential Store](http://docs.aws.amazon.com/powershell/latest/userguide/specifying-your-aws-credentials.html) - run ResetCredentials.bat from the repository root with appropriate parameters to do this

## Instructions

1. Navigate to .\Exercise2 and open Deploy.ps1 in Powershell ISE
2. Spend a some time getting familiar with what it is doing
* How does the template get from our local machine to AWS? 
* How do we supply parameters that our CloudFormation template requires? 
3. Open .\Exercise2\Parameters.ps1. Update the ResourcePrefix parameter to your initials, and take note of the other parameters provided
4. Create an empty file named Webserver.template in .\Exercise2\Templates
5. Build your template's [Skeleton Structure](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-anatomy.html)
6. Define your [Security Group Template](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-security-group.html)
* Refer to the [samples available](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/sample-templates-services-us-west-2.html#d0e111750) if you need a more complete sample to work from
7. Define your [EC2 Instance Template](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-ec2-instance.html)
8. Kick off .\Deploy.ps1 by F5-ing it in ISE, and open the CloudFormation section of the AWS console
9. Monitor your stack's creation by opening the 'Events' tab for a running summary of progress
10. If something fails, analyse the error. What went wrong? Double check your template, and the template documentation. Feel free to grab someone to rubber duck!
11. If it is all green, jump into the EC2 console and try to remote into your instance
12. Great success!

Note: If you installed the [Visual Studio Tooling](http://blog.kloud.com.au/2015/05/18/create-aws-cloudformation-templates-with-visual-studio/) you can use an "AWS CloudFormation project" to work with your template, which will give you some intellisense out of the box.
