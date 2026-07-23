#-------------------------------------------------------------------------------
# AgentCore Memory: short-term events per email thread (session) and long-term
# records per sender (actor), extracted asynchronously by built-in strategies.
#-------------------------------------------------------------------------------

resource "aws_bedrockagentcore_memory" "email_agent" {
  # AgentCore memory names do not allow hyphens
  name                  = replace("${local.id}_memory", "-", "_")
  description           = "${local.id} conversation memory"
  event_expiry_duration = 30

  tags = local.tags
}

# Namespaces here must match the retrieval_config namespaces in src/agent.py.
resource "aws_bedrockagentcore_memory_strategy" "facts" {
  name        = "facts"
  memory_id   = aws_bedrockagentcore_memory.email_agent.id
  type        = "SEMANTIC"
  description = "Factual information about the sender across threads"
  namespaces  = ["/facts/{actorId}"]
}

resource "aws_bedrockagentcore_memory_strategy" "preferences" {
  name        = "preferences"
  memory_id   = aws_bedrockagentcore_memory.email_agent.id
  type        = "USER_PREFERENCE"
  description = "Sender preferences across threads"
  namespaces  = ["/preferences/{actorId}"]
}
