#!/bin/sh
# ---------------------------------------------------------------------------
# localstack-init.sh
# Creates all SQS queues and their DLQs inside LocalStack on startup.
# Run as the sqs-init one-shot container in docker-compose.yml.
# ---------------------------------------------------------------------------

ENDPOINT=http://localstack:4566

create_dlq_pair() {
  MAIN=$1
  DLQ="${MAIN}-dlq"

  echo "Creating DLQ: $DLQ"
  DLQ_URL=$(aws --endpoint-url=$ENDPOINT sqs create-queue \
    --queue-name $DLQ \
    --query QueueUrl --output text)

  DLQ_ARN=$(aws --endpoint-url=$ENDPOINT sqs get-queue-attributes \
    --queue-url $DLQ_URL \
    --attribute-names QueueArn \
    --query Attributes.QueueArn --output text)

  echo "Creating queue: $MAIN (redrive → $DLQ)"
  aws --endpoint-url=$ENDPOINT sqs create-queue \
    --queue-name $MAIN \
    --attributes "{
      \"RedrivePolicy\": \"{\\\"deadLetterTargetArn\\\":\\\"$DLQ_ARN\\\",\\\"maxReceiveCount\\\":\\\"3\\\"}\"
    }"

  echo "✅ $MAIN → $DLQ"
}

# Notification queues
create_dlq_pair pharmadesk-email
create_dlq_pair pharmadesk-push
create_dlq_pair pharmadesk-alerts

# Analytics queue
create_dlq_pair pharmadesk-domain-events

echo ""
echo "All SQS queues created."
aws --endpoint-url=$ENDPOINT sqs list-queues --region ap-southeast-1
