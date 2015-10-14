$Parameters = @{}

# Octopus parameters
$Parameters['ResourcePrefix'] = "";
$Parameters['Environment'] = "CI";
$Parameters['Version'] = "1.0.0";

# CloudFormation parameters
$Parameters['AWSRegion'] = "ap-southeast-2";
$Parameters['CloudFormationStackName'] = "{0}-simple-sandbox-{1}" -f @($Parameters['ResourcePrefix'], $Parameters['Environment']);
$Parameters['S3BucketName'] = "{0}-simple-sandbox-infrastructure" -f $Parameters['ResourcePrefix'];
$Parameters['VpcId'] = "";

# AWS parameters
$Parameters['KeyPairName'] = "";
$Parameters['WebserverImageId'] = ""; #WINDOWS_2012R2_BASE
$Parameters['WebserverInstanceType'] = "t2.medium";
$Parameters['WebserverSubnetId'] = ""; # Public A