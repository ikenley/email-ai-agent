"""MIME parsing and reply construction helpers."""

import html
import re
from email import message_from_bytes, policy
from email.message import EmailMessage


def extract_plaintext(raw_bytes):
    """Parse a raw MIME message and return (message, plaintext body)."""
    message = message_from_bytes(raw_bytes, policy=policy.default)
    part = message.get_body(preferencelist=("plain", "html"))
    if part is None:
        return message, ""
    text = part.get_content()
    if part.get_content_type() == "text/html":
        text = _strip_html(text)
    return message, text


def _strip_html(markup):
    text = re.sub(r"<(script|style).*?</\1>", "", markup, flags=re.DOTALL | re.IGNORECASE)
    text = re.sub(r"<[^>]+>", "", text)
    text = html.unescape(text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def build_reply(original, reply_text, from_address, to_address):
    """Build a reply that threads under the original message in mail clients."""
    reply = EmailMessage()

    subject = original.get("Subject", "") or ""
    if not subject.lower().startswith("re:"):
        subject = f"Re: {subject}".strip()
    reply["Subject"] = subject
    reply["From"] = from_address
    reply["To"] = to_address

    original_id = original.get("Message-ID")
    if original_id:
        reply["In-Reply-To"] = original_id
        references = original.get("References", "") or ""
        reply["References"] = f"{references} {original_id}".strip()

    reply.set_content(reply_text)
    return reply
