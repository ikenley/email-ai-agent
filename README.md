# email-ai-agent

Email ingress AI agent loop. Send an email to `agent@aimail.ikenley.com` and a
Strands agent on Bedrock replies.

## How it works

```
email → Route53 MX → SES receipt rule ─┬→ S3 (raw MIME, 30-day expiry)
                                       └→ Lambda (async)
                                            1. SPF/DKIM verdict check
                                            2. sender in DynamoDB allowlist?
                                            3. fetch + parse MIME from S3
                                            4. Strands agent on Bedrock
                                            5. reply via ses:SendRawEmail
```

Stateless: each email is answered independently. Unauthorized senders are
silently dropped.

## Deploy

1. Provision infrastructure (creates ECR repo, Lambda with a placeholder
   image, S3 bucket, SES domain identity + DNS + receipt rules):

   ```sh
   cd iac/projects/dev
   terraform init && terraform apply
   ```

2. Build and push the Lambda image:

   ```sh
   ./src/build_and_push.sh
   ```

3. Authorize a sender by adding their address as a `hash_key` item in the
   allowlist DynamoDB table (see `allowed_email_addresses_dynamo_table_name`
   in `iac/projects/dev/terraform.tfvars`).

4. Email `agent@aimail.ikenley.com`.

Logs: CloudWatch log group `/aws/lambda/ik-dev-email-ai-agent-lambda`.
