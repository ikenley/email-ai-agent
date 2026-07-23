"""Strands agent wrapper around Bedrock with AgentCore Memory."""

import os

from bedrock_agentcore.memory.integrations.strands.config import (
    AgentCoreMemoryConfig,
    RetrievalConfig,
)
from bedrock_agentcore.memory.integrations.strands.session_manager import (
    AgentCoreMemorySessionManager,
)
from strands import Agent
from strands.models import BedrockModel

SYSTEM_PROMPT = (
    "You are a helpful assistant that chats over email. "
    "Reply in plain text suitable for an email body: no markdown formatting "
    "unless the user asks for code. Be concise and friendly. "
    "You may have memory of earlier messages in this thread and of past "
    "conversations with this sender; use it naturally when relevant."
)


def run_agent(prompt: str, actor_id: str, session_id: str) -> str:
    model = BedrockModel(model_id=os.environ["BEDROCK_MODEL_ID"])

    # Namespaces must match the strategy namespaces in
    # iac/modules/main/agentcore.tf.
    memory_config = AgentCoreMemoryConfig(
        memory_id=os.environ["AGENTCORE_MEMORY_ID"],
        actor_id=actor_id,
        session_id=session_id,
        retrieval_config={
            "/facts/{actorId}": RetrievalConfig(top_k=10, relevance_score=0.3),
            "/preferences/{actorId}": RetrievalConfig(top_k=5, relevance_score=0.5),
        },
    )

    # bedrock-agentcore 0.1.x writes each message through synchronously and is
    # not a context manager; there is no buffer to flush.
    session_manager = AgentCoreMemorySessionManager(
        agentcore_memory_config=memory_config,
        region_name=os.environ["AWS_REGION"],
    )
    agent = Agent(
        model=model,
        system_prompt=SYSTEM_PROMPT,
        callback_handler=None,
        session_manager=session_manager,
    )
    result = agent(prompt)
    return str(result)
