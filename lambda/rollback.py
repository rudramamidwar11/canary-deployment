import boto3, json, os, logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    ssm = boto3.client('ssm')
    instance_id  = os.environ['EC2_INSTANCE_ID']
    project_name = os.environ['PROJECT_NAME']

    logger.info(f"Rollback triggered. Instance: {instance_id}")
    logger.info(f"Event: {json.dumps(event)}")

    # Only rollback if alarm is actually in ALARM state
    alarm_state = event.get('alarmData', {}).get('state', {}).get('value', 'ALARM')
    if alarm_state != 'ALARM':
        logger.info("Alarm not in ALARM state — skipping rollback")
        return {'statusCode': 200, 'body': 'Skipped'}

    try:
        response = ssm.send_command(
            InstanceIds=[instance_id],
            DocumentName='AWS-RunShellScript',
            Parameters={
                'commands': [
                    'echo "Lambda rollback triggered at $(date)" >> /home/ec2-user/logs/rollback.log',
                    'sudo -u ec2-user bash /home/ec2-user/scripts/rollback.sh >> /home/ec2-user/logs/rollback.log 2>&1'
                ]
            },
            Comment=f'Auto-rollback by {project_name}',
            TimeoutSeconds=120
        )
        cmd_id = response['Command']['CommandId']
        logger.info(f"SSM command sent: {cmd_id}")
        return {'statusCode': 200, 'body': json.dumps({'commandId': cmd_id})}

    except Exception as e:
        logger.error(f"Rollback failed: {e}")
        raise