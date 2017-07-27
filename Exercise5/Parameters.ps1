$OctopusParameters = @{}

# Octopus parameters
$OctopusParameters['ResourcePrefix'] = 'aab';
$OctopusParameters['OctopusServerUrl'] = "http://octopus.cfa.aws";
$OctopusParameters['OctopusRole'] = "web";
$OctopusParameters['OctopusApiKey'] = "";
$OctopusParameters['Octopus.Environment.Name'] = "Production";
$OctopusParameters['Octopus.Release.Number'] = "1.0.0-ryan0001";

# CloudFormation parameters
$OctopusParameters['AWSRegion'] = "ap-southeast-2";
$OctopusParameters['CloudFormationStackName'] = "{0}-sandbox-{1}" -f @($OctopusParameters['ResourcePrefix'], $OctopusParameters['Octopus.Environment.Name']);
$OctopusParameters['S3BucketName'] = "{0}-sandbox-infrastructure" -f $OctopusParameters['ResourcePrefix'];
$OctopusParameters['VpcId'] = "vpc-7ecaee1b";

# AWS parameters
$OctopusParameters['KeyPairName'] = "AwsDayKeyPair";
$OctopusParameters['WebserverImageId'] = "ami-bf8895dc"; #WINDOWS_2016_BASE
$OctopusParameters['WebserverInstanceType'] = "t2.medium";
$OctopusParameters['WebserverSubnetIdAzOne'] = "subnet-b1afb5d4"; # Web A
$OctopusParameters['WebserverSubnetIdAzTwo'] = "subnet-14787e63"; # Web B
$OctopusParameters['LoadBalancerSubnetIdAzOne'] = "subnet-973728f2"; # DMZ A
$OctopusParameters['LoadBalancerSubnetIdAzTwo'] = "subnet-99477cee"; # DMZ B