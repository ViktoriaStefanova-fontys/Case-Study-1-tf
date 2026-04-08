# Resources:
# aws_wafv2_ip_set                        (permanent block list)
# aws_wafv2_web_acl                       (WAF attached to the ALB)
# aws_wafv2_web_acl_association
# aws_cloudwatch_metric_alarm             (fires when rate rule triggers)
# aws_cloudwatch_event_rule               (EventBridge — reacts to alarm)
# aws_cloudwatch_event_target             (EventBridge → Lambda)
# aws_lambda_function                     (responder)
# aws_lambda_permission                   (allow EventBridge to invoke Lambda)
# aws_sns_topic + subscription
# aws_iam_role + policy                   (Lambda execution role)


# manual ip set in which lambda will add ips
resource "aws_wafv2_ip_set" "blocked_ips" {
  name               = "blocked-ips"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = []

  tags = {
    Name = "Blocked IPs"
  }
}


# WAF web ACL 
resource "aws_wafv2_web_acl" "web_acl" {
  name  = "web-acl"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: block IPs that Lambda has permanently added to the IP set
  rule {
    name     = "BlockListedIPs"
    priority = 1

    action {
      block {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.blocked_ips.arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true # enable cloudwatch to setup the alarm
      metric_name                = "BlockListedIPs"
      sampled_requests_enabled   = true
    }
  }

  # rule 2: rate-based rule: WAF temporarily blocks IPs exceeding the limit of requests

  rule {
    name     = "RateBasedRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    # cloudWatch metric which triggers the alarm
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateBasedRule"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "web-acl"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "Web ACL"
  }
}


# attach WAF to ALB 

resource "aws_wafv2_web_acl_association" "web_alb" {
  resource_arn = aws_lb.web_server_lb.arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}


########## CloudWatch Alarm ##############
# WAF publishes a metric called "BlockedRequests", when this metric goes above 0, 
# it means the rate-based rule has started blocking an IP, which is the trigger signal.

resource "aws_cloudwatch_metric_alarm" "waf_rate_alarm" {
  alarm_name          = "waf-rate-limit-triggered"
  alarm_description   = "Fires when the WAF rate-based rule blocks at least one request"
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 300 # 5-minute window, matches WAF's own evaluation window
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.web_acl.name
    Region = var.aws_region
    Rule   = "RateBasedRule"
  }

  tags = {
    Name = "WAF Rate Alarm"
  }
}


####### EventBridge rule- Watches for the CloudWatch Alarm to change to ALARM state, which wakes Lambda up

resource "aws_cloudwatch_event_rule" "alarm_to_lambda" {
  name        = "waf-rate-alarm-state-change"
  description = "Triggers Lambda when WAF rate alarm enters ALARM state"

  event_pattern = jsonencode({
    source      = ["aws.cloudwatch"]
    detail-type = ["CloudWatch Alarm State Change"]
    resources   = [aws_cloudwatch_metric_alarm.waf_rate_alarm.arn]
    detail = {
      state = {
        value = ["ALARM"]
      }
    }
  })

  tags = {
    Name = "Alarm to Lambda"
  }
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule = aws_cloudwatch_event_rule.alarm_to_lambda.name
  arn  = aws_lambda_function.block_ips.arn
}


# SNS topic + email subscription 
resource "aws_sns_topic" "waf_alerts" {
  name = "waf-alerts"

  tags = {
    Name = "WAF Alerts"
  }
}

resource "aws_sns_topic_subscription" "block_ips_email" {
  topic_arn = aws_sns_topic.waf_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


# ── IAM role for Lambda ───────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name = "Lambda Role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_policy" "get_ips_lambda_policy" {
  name = "get-ips-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WAFReadRateLimitedIPs"
        Effect = "Allow"
        Action = [
          "wafv2:GetRateBasedStatementManagedKeys",
        ]
        # This action requires * as resource — AWS does not support
        # resource-level permissions for this specific API call
        Resource = "*"
      },
      {
        Sid    = "WAFIPSetAccess"
        Effect = "Allow"
        Action = [
          "wafv2:GetIPSet",
          "wafv2:UpdateIPSet",
        ]
        Resource = aws_wafv2_ip_set.blocked_ips.arn
      },
      {
        Sid      = "SNSPublish"
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = aws_sns_topic.waf_alerts.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_custom" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.get_ips_lambda_policy.arn
}


# ── Lambda function ───────────────────────────────────────────────────────────

data "archive_file" "block_ips" {
  type        = "zip"
  source_file = "${path.module}/lambda/block_ips.py"
  output_path = "${path.module}/lambda/block_ips.zip"
}

resource "aws_lambda_function" "block_ips" {
  function_name    = "block_ips"
  role             = aws_iam_role.lambda_role.arn
  runtime          = "python3.12"
  handler          = "block_ips.lambda_handler"
  filename         = data.archive_file.block_ips.output_path
  source_code_hash = data.archive_file.block_ips.output_base64sha256

  timeout     = 30
  memory_size = 128

  environment {
    variables = {
      WEB_ACL_NAME   = aws_wafv2_web_acl.web_acl.name
      WEB_ACL_ID     = aws_wafv2_web_acl.web_acl.id
      RATE_RULE_NAME = "RateBasedRule"
      IP_SET_NAME    = aws_wafv2_ip_set.blocked_ips.name
      IP_SET_ID      = aws_wafv2_ip_set.blocked_ips.id
      SNS_TOPIC_ARN  = aws_sns_topic.waf_alerts.arn
    }
  }

  tags = {
    Name = "WAF Responder"
  }
}


# ── Allow EventBridge to invoke Lambda ───────────────────────────────────────

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.block_ips.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_to_lambda.arn
}


# ── CloudWatch log group for Lambda's own logs ────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.block_ips.function_name}"
  retention_in_days = 7

  tags = {
    Name = "Lambda Logs"
  }
}
