$Parameters = @{}

# Octopus parameters
$Parameters['ResourcePrefix'] = "ab";
$Parameters['Environment'] = "CI";
$Parameters['Version'] = "1.0.0";

# CloudFormation parameters
$Parameters['AWSRegion'] = "us-west-2";
$Parameters['CloudFormationStackName'] = "{0}-simple-sandbox-{1}" -f @($Parameters['ResourcePrefix'], $Parameters['Environment']);
$Parameters['S3BucketName'] = "{0}-simple-sandbox-infrastructure" -f $Parameters['ResourcePrefix'];
$Parameters['VpcId'] = "vpc-a8450bcd";

# AWS parameters
$Parameters['KeyPairName'] = "AwsDayKeyPair";
$Parameters['WebserverImageId'] = "ami-dfccd1ef"; #WINDOWS_2012R2_BASE
$Parameters['WebserverInstanceType'] = "t2.small";
$Parameters['WebserverSubnetId'] = "subnet-3a8bf94d"; # Public A