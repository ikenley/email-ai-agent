"""Strands agent wrapper around Bedrock."""

import os

from strands import Agent
from strands.models import BedrockModel

SYSTEM_PROMPT = (
    "You are a helpful assistant that chats over email. "
    "Reply in plain text suitable for an email body: no markdown formatting "
    "unless the user asks for code. Be concise and friendly. "
    "The email may include quoted text from earlier in the thread; treat the "
    "newest (unquoted) text as the user's message."
)


def run_agent(prompt: str) -> str:
    model = BedrockModel(model_id=os.environ["BEDROCK_MODEL_ID"])
    agent = Agent(model=model, system_prompt=SYSTEM_PROMPT, callback_handler=None)
    result = agent(prompt)
    return str(result)
