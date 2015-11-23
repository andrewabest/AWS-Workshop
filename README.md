# AWS-Workshop
Workshop content for automated delivery in AWS for .NET

## Prerequisites

You will need to have installed [The AWS.NET SDK](https://aws.amazon.com/sdk-for-net/). You could optionally install The [AWS VS Tooling](http://aws.amazon.com/visualstudio/) instead which includes the SDK, and also gives you intellisense for CloudFormation templates.

The samples within assume you are using the [AWS SDK Credential Store](http://docs.aws.amazon.com/powershell/latest/userguide/specifying-your-aws-credentials.html). You will need to store an appropriate set of credentials under the "AWSWorkshop" profile to execute the samples. *ResetCredentials.bat* will help accomplish this.

## Itinerary

* Working securely in AWS
* [AWS a-b-c's](https://speakerdeck.com/andrewabest/aws-a-b-cs)
* [Exercise One - DIY](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise1.md)
* CloudFormation Introduction ([supplementary information](http://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cfn-whatis-howdoesitwork.html))
* [Exercise Two - CloudFormation](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise2.md)
* Question Time
* [DSC a-b-c's](https://speakerdeck.com/andrewabest/dsc-a-b-cs)
* [Exercise Three - DSC DIY](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise3.md)
* Question Time
* [Exercise Four - CloudFormation + DSC](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise4.md)
* [Exercise Five - CloudFormation + DSC + Octopus (Form like Voltron)](https://github.com/andrewabest/AWS-Workshop/blob/master/Exercise5.md)
* Discussion time - Automating infrastructure

### Disclaimer

What is presented here is 101 level infrastructure automation, and is not intended as a production solution. Most production rollouts in AWS will involve a significantly more complex setup to enforce appropriate security and scalability - for a reference architecture, see [Amazon's examples](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Scenario3.html).
