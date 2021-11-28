#!/usr/bin/env sh

# Input parameters required are in order:
SITE_NAME=${1//_/-}
UPLOAD_USER=$2
HOSTED_ZONE_ID=$3
SITE_TYPE=$4

if [ "$SITE_NAME" == "" ]; then
	echo "Name of website required."
	exit 1;
fi

if [ "$SITE_TYPE" == "" ]; then
	SITE_TYPE="S3"
fi

declare -a PARAMETERS=(
	"ParameterKey=SiteName,ParameterValue=$SITE_NAME"
	"ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID"
	"ParameterKey=SiteType,ParameterValue=$SITE_TYPE"
	"ParameterKey=UploadUser,ParameterValue=$UPLOAD_USER"
)

STACK_NAME="$SITE_NAME-stack"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TEMPLATE_BODY="file://$DIR/cloudformation.json"

if [ "$SITE_TYPE" == "CloudFront" ]; then
	declare -a CERTIFICATE_PARAMETERS=(
		"ParameterKey=SiteName,ParameterValue=$SITE_NAME"
		"ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID"
	)
	CERTIFICATE_PARAMETERS_JOINED=$(IFS=$' '; echo "${CERTIFICATE_PARAMETERS[*]}")

	CERTIFICATE_STACK_NAME="$SITE_NAME-certificate-stack"
	CERTIFICATE_TEMPLATE_BODY="file://$DIR/certificate.json"

	if aws cloudformation --region us-east-1 list-stacks --query "StackSummaries[*].StackName" | grep -q $CERTIFICATE_STACK_NAME ; then
		aws cloudformation update-stack --region us-east-1 --stack-name $CERTIFICATE_STACK_NAME --template-body $CERTIFICATE_TEMPLATE_BODY --parameters $CERTIFICATE_PARAMETERS_JOINED
	else
		aws cloudformation create-stack --region us-east-1 --stack-name $CERTIFICATE_STACK_NAME --template-body $CERTIFICATE_TEMPLATE_BODY --parameters $CERTIFICATE_PARAMETERS_JOINED
	fi

	CERTIFICATE_ARN=$(aws cloudformation --region us-east-1 describe-stacks --stack-name $CERTIFICATE_STACK_NAME --query "Stacks[0].Outputs[0].OutputValue")
	
	if echo $CERTIFICATE_ARN | grep -q "arn:aws:acm:us-east-1:" ; then
		PARAMETERS+=("ParameterKey=SiteCertificateArn,ParameterValue=$CERTIFICATE_ARN")
	else
		echo "Site certificate currently not present, please try again in a short time"
		exit 1;
	fi
fi

PARAMETERS_JOINED=$(IFS=$' '; echo "${PARAMETERS[*]}")

if aws cloudformation --region eu-west-1 list-stacks --query "StackSummaries[*].StackName" | grep -q $STACK_NAME ; then
	aws cloudformation update-stack --region eu-west-1 --stack-name $STACK_NAME --template-body $TEMPLATE_BODY --parameters $PARAMETERS_JOINED --capabilities CAPABILITY_NAMED_IAM
else
	aws cloudformation create-stack --region eu-west-1 --stack-name $STACK_NAME --template-body $TEMPLATE_BODY --parameters $PARAMETERS_JOINED --capabilities CAPABILITY_NAMED_IAM
fi

echo "CloudFormation stacks deploying, or already up to date"

if [ $UPLOAD_USER != "True" ] ; then
	if echo `aws s3 ls` | grep -q "$SITE_NAME.com" ; then
		aws s3 sync $DIR/checkout/ s3://"$SITE_NAME.com"/ --sse --delete
	else
		echo "S3 Bucket currently not available, please try again in a short time"
	fi
fi
