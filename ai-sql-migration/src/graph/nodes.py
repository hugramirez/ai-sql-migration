"""LLM and tool nodes (quickstart logic)."""

from __future__ import annotations

from typing import Any

from langchain_core.messages import SystemMessage, ToolMessage
from langgraph.graph import END

from src.graph.state import MessagesState


def make_llm_call_node(model_with_tools: Any, system_prompt: str):
    def llm_call(state: dict):
        return {
            "messages": [
                model_with_tools.invoke(
                    [SystemMessage(content=system_prompt)] + state["messages"]
                )
            ],
            "llm_calls": state.get("llm_calls", 0) + 1,
        }

    return llm_call


def make_tool_node(tools_by_name: dict):
    def tool_node(state: dict):
        result = []
        for tool_call in state["messages"][-1].tool_calls:
            tool = tools_by_name[tool_call["name"]]
            try:
                observation = tool.invoke(tool_call["args"])
            except Exception as exc:
                observation = f"Tool error: {type(exc).__name__}: {exc}"
            result.append(
                ToolMessage(
                    content=observation,
                    tool_call_id=tool_call["id"],
                )
            )
        return {"messages": result}

    return tool_node


def should_continue(state: MessagesState):
    """Route to tools or stop, per quickstart."""
    messages = state["messages"]
    last_message = messages[-1]
    if last_message.tool_calls:
        return "tool_node"
    return END
