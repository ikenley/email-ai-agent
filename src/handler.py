"""Entry point for the SES-triggered email AI agent."""

import hashlib
import logging
import os
import re
from email.utils import parseaddr

import boto3

from agent import run_agent
from email_utils import build_reply, extract_plaintext, strip_quoted_text, thread_root_id

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
dynamodb = boto3.client("dynamodb")
ses = boto3.client("ses")

INBOUND_MAIL_BUCKET = os.environ["INBOUND_MAIL_BUCKET"]
ALLOWED_EMAIL_TABLE = os.environ["ALLOWED_EMAIL_TABLE"]
AGENT_EMAIL_ADDRESS = os.environ["AGENT_EMAIL_ADDRESS"]


def lambda_handler(event, context):
    record = event["Records"][0]["ses"]
    mail = record["mail"]
    receipt = record["receipt"]

    message_id = mail["messageId"]
    _, sender = parseaddr(mail["commonHeaders"]["from"][0])
    sender = sender.lower()

    if not is_authenticated(receipt):
        logger.info("Dropping %s: SPF and DKIM both failed for %s", message_id, sender)
        return

    if not is_allowed(sender):
        logger.info("Dropping %s: sender %s not in allowlist", message_id, sender)
        return

    raw = s3.get_object(Bucket=INBOUND_MAIL_BUCKET, Key=f"inbound/{message_id}")["Body"].read()
    original, body = extract_plaintext(raw)
    body = strip_quoted_text(body)
    if not body.strip():
        logger.info("Dropping %s: no readable text body", message_id)
        return

    # AgentCore Memory identities: actor = sender (allows [a-zA-Z0-9-_/:]),
    # session = email thread (allows [a-zA-Z0-9-_], max 100 chars, so hash the
    # root Message-ID).
    actor_id = re.sub(r"[^a-zA-Z0-9\-_/]", "_", sender)
    session_id = hashlib.sha256(thread_root_id(original).encode()).hexdigest()

    logger.info("Running agent for %s (%d chars, session %s)", sender, len(body), session_id[:12])
    reply_text = run_agent(body, actor_id=actor_id, session_id=session_id)

    reply = build_reply(
        original,
        reply_text,
        from_address=AGENT_EMAIL_ADDRESS,
        to_address=sender,
    )
    ses.send_raw_email(RawMessage={"Data": reply.as_bytes()})
    logger.info("Replied to %s for %s", sender, message_id)


def is_authenticated(receipt):
    """Require SPF or DKIM to pass; From headers alone are trivially spoofed."""
    return "PASS" in (
        receipt.get("spfVerdict", {}).get("status"),
        receipt.get("dkimVerdict", {}).get("status"),
    )


def is_allowed(sender):
    """Check if the sender is in the allowlist DynamoDB table."""

    # Hash format is "i:<lowercase email address>".
    email_hash = f"i:{sender.lower()}"

    response = dynamodb.get_item(
        TableName=ALLOWED_EMAIL_TABLE,
        Key={"hash_key": {"S": email_hash}, "range_key": {"S": "i"}},
    )
    return "Item" in response
