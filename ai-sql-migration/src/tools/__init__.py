"""Tools package.

We keep a minimal stub to unblock imports while the real Databricks tools
are being implemented.
"""

from __future__ import annotations

from typing import Any
from src.tools.databricks_sql import describe_table, run_sql_query

def get_agent_tools() -> list[Any]:
    """Return tool instances compatible with LangChain tool calling."""
    return [run_sql_query, describe_table]

__all__ = ["get_agent_tools"]
