$Parameters = @{}

# Octopus parameters
$Parameters['ResourcePrefix'] = "aab";
$Parameters['Environment'] = "Production";
$Parameters['Version'] = "1.0.0-ryan0001";

# CloudFormation parameters
$Parameters['AWSRegion'] = "ap-southeast-2";
$Parameters['CloudFormationStackName'] = "{0}-simple-sandbox-{1}" -f @($Parameters['ResourcePrefix'], $Parameters['Environment']);
$Parameters['S3BucketName'] = "{0}-simple-sandbox-infrastructure" -f $Parameters['ResourcePrefix'];
$Parameters['VpcId'] = "vpc-7ecaee1b";

# AWS parameters
$Parameters['KeyPairName'] = "AwsDayKeyPair";
$Parameters['WebserverImageId'] = "ami-bf8895dc"; #WINDOWS_2016_BASE
$Parameters['WebserverInstanceType'] = "t2.medium";
$Parameters['WebserverSubnetId'] = "subnet-99477cee"; # DMZ B