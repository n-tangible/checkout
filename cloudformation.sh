#!/usr/bin/env sh

# Input parameters required are in order:
SITE_NAME=${1//_/-}
CUSTOM_DOMAIN=$2

if [ "$SITE_NAME" == "" ]; then
	echo "Name of website required."
	exit 1;
fi

declare -a PARAMETERS=(
	"ParameterKey=SiteName,ParameterValue=$SITE_NAME"
	"ParameterKey=CustomDomain,ParameterValue=$CUSTOM_DOMAIN"
)
PARAMETERS_JOINED=$(IFS=$' '; echo "${PARAMETERS[*]}")

STACK_NAME="$SITE_NAME-stack"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TEMPLATE_BODY="file://$DIR/cloudformation.json"

if aws cloudformation --region eu-west-1 list-stacks --query "StackSummaries[*].StackName" | grep -q $STACK_NAME ; then
	aws cloudformation update-stack --region eu-west-1 --stack-name $STACK_NAME --template-body $TEMPLATE_BODY --parameters $PARAMETERS_JOINED
else
	aws cloudformation create-stack --region eu-west-1 --stack-name $STACK_NAME --template-body $TEMPLATE_BODY --parameters $PARAMETERS_JOINED
fi

if echo `aws s3 ls` | grep -q "$SITE_NAME.com" ; then
	aws s3 cp $DIR/checkout/ s3://"$SITE_NAME.com"/ --sse --recursive
fi
