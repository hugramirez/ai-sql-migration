"""Compile the Databricks agent graph."""

from __future__ import annotations

from langgraph.graph import END, START, StateGraph

from src.config.llm_config import create_anthropic_model, create_chat_model, create_openrouter_model
from src.config.settings import Settings
from src.graph.nodes import make_llm_call_node, make_tool_node, should_continue
from src.graph.state import MessagesState
from src.tools import get_agent_tools


def build_agent(settings: Settings, tier: str = "complex"):
    """Build and compile the Databricks tool-calling agent."""
    if settings.openrouter_api_key:
        model = create_openrouter_model(settings, tier)
    else:
        model = create_anthropic_model(settings, tier)
    tools = get_agent_tools()
    tools_by_name = {t.name: t for t in tools}
    model_with_tools = model.bind_tools(tools)

    llm_call = make_llm_call_node(model_with_tools, settings.system_prompt)
    tool_node = make_tool_node(tools_by_name)

    agent_builder = StateGraph(MessagesState)
    agent_builder.add_node("llm_call", llm_call)
    agent_builder.add_node("tool_node", tool_node)
    agent_builder.add_edge(START, "llm_call")
    agent_builder.add_conditional_edges(
        "llm_call",
        should_continue,
        ["tool_node", END],
    )
    agent_builder.add_edge("tool_node", "llm_call")
    return agent_builder.compile()


if __name__ == "__main__":
    settings = Settings.from_env()
    agent = build_agent(settings)
    print(agent)