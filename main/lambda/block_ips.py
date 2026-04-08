import boto3
import logging
import os
 
logger = logging.getLogger()
logger.setLevel(logging.INFO)
 
wafv2 = boto3.client("wafv2", region_name=os.environ["AWS_REGION"])
sns   = boto3.client("sns",   region_name=os.environ["AWS_REGION"])
 
SCOPE = "REGIONAL"
 
 
def lambda_handler(event, context):
    logger.info("SOAR triggered by CloudWatch Alarm state change")
 
    # get IPs currently rate-limited by WAF
    response = wafv2.get_rate_based_statement_managed_keys(
        Scope=SCOPE,
        WebACLName=os.environ["WEB_ACL_NAME"],
        WebACLId=os.environ["WEB_ACL_ID"],
        RuleName=os.environ["RATE_RULE_NAME"],
    )
    ips_to_block = response["ManagedKeysIPV4"]["Addresses"]
    logger.info("WAF is currently rate-limiting: %s", ips_to_block)
 
    if not ips_to_block:
        logger.info("No IPs currently rate-limited, nothing to do")
        return {"statusCode": 200}
 
    # fetch current IP set state (lock token is required by WAF to update)
    ip_set = wafv2.get_ip_set(
        Name=os.environ["IP_SET_NAME"],
        Scope=SCOPE,
        Id=os.environ["IP_SET_ID"],
    )
    merged = list(set(ip_set["IPSet"]["Addresses"]) | set(ips_to_block))
 
    # permanently add IPs to the block list
    wafv2.update_ip_set(
        Name=os.environ["IP_SET_NAME"],
        Scope=SCOPE,
        Id=os.environ["IP_SET_ID"],
        Addresses=merged,
        LockToken=ip_set["LockToken"],
    )
    logger.info("Successfully added %s to WAF IP set", ips_to_block)
 
    # send email alert
    sns.publish(
        TopicArn=os.environ["SNS_TOPIC_ARN"],
        Subject="[SOAR] HTTP Flood Blocked",
        Message=f"Blocked IPs: {', '.join(ips_to_block)}",
    )
    logger.info("SNS alert sent")
 