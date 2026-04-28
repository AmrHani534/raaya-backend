# Raaya Backend - Operations Runbook

## 1. Check API Health

## 8. Pending Resources (Lambda & EventBridge) - Future Setup
*Note: Run these commands once the scheduled jobs (e.g., Medication Reminders, AI Summaries) are provisioned.*

### A. Create Lambda Error Alarm
aws cloudwatch put-metric-alarm `
  --alarm-name "raaya-lambda-errors" `
  --alarm-description "Alarm when Lambda functions experience errors" `
  --metric-name Errors `
  --namespace AWS/Lambda `
  --statistic Sum `
  --period 300 `
  --threshold 1 `
  --comparison-operator GreaterThanOrEqualToThreshold `
  --evaluation-periods 1 `
  --treat-missing-data notBreaching

### B. Check Lambda Logs
aws logs tail /aws/lambda/<your-lambda-function-name> --follow

### C. Check EventBridge Scheduler Logs
*Logs will be accessible in CloudWatch under the specific target log group configured during the EventBridge scheduler setup.*