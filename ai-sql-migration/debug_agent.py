#!/usr/bin/env python
"""Debug script to test agent invocation."""

import os
from langchain_core.messages import HumanMessage
from src.config.settings import Settings
from src.graph.builder import build_agent

settings = Settings.from_env()
agent = build_agent(settings)

query = "Use describe_table for localuc.bronze.raw_dim_patient and show me the columns."
messages = [HumanMessage(content=query)]

print(f"Query: {query}")
print(f"Invoking agent with {len(messages)} message(s)...\n")

try:
    result = agent.invoke({"messages": messages})
    print(f"\nAgent returned. Result has {len(result['messages'])} messages:")
    
    for i, msg in enumerate(result["messages"]):
        print(f"\n  Message {i}: {type(msg).__name__}")
        if hasattr(msg, "content"):
            content_preview = str(msg.content)[:100]
            print(f"    Content preview: {content_preview}...")
        if hasattr(msg, "tool_calls"):
            print(f"    Tool calls: {msg.tool_calls}")
except Exception as e:
    print(f"ERROR: {type(e).__name__}: {e}")
    import traceback
    traceback.print_exc()
