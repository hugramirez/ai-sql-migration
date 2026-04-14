"""Tools available to the agent.

This repo currently doesn't define Databricks tool implementations yet.
We provide a minimal stub so `src.graph.builder` can import and compile.
"""

from __future__ import annotations

from typing import Any


def get_agent_tools() -> list[Any]:
    """Return tool instances compatible with LangChain tool calling."""
    # TODO: Implement Databricks-backed tools (query execution, schema lookup, etc).
    return []

