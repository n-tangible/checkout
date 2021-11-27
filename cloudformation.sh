#!/usr/bin/env sh

# Input parameters required are in order:
BUCKET_NAME=${1//_/-}

if [ "$BUCKET_NAME" == "" ]; then
	BUCKET_NAME="checkout-devops-challenge"
fi

declare -a PARAMETERS=(
	"ParameterKey=BucketName,ParameterValue=$BUCKET_NAME"
)
PARAMETERS_JOINED=$(IFS=$' '; echo "${PARAMETERS[*]}")

STACK_NAME="$BUCKET_NAME-stack"

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
TEMPLATE_BODY="file://$DIR/cloudformation.json"

if aws cloudformation list-stacks --query "StackSummaries[*].StackName" | grep -q $STACK_NAME ; then
	aws cloudformation update-stack --stack-name $STACK_NAME --template-body $TEMPLATE_BODY --parameters $PARAMETERS_JOINED
else
	aws cloudformation create-stack --stack-name $STACK_NAME --template-body $TEMPLATE_BODY --parameters $PARAMETERS_JOINED
fi

if echo `aws s3 ls` | grep -q $BUCKET_NAME ; then
	aws s3 cp $DIR/checkout/ s3://$BUCKET_NAME/ --sse --recursive
fi
