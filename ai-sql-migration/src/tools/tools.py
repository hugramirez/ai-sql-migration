"""Tools available to the agent.

Registers all tool implementations for the LangGraph agent:
- Databricks SQL tools (run_sql_query, describe_table)
- SQL Edge tools (run_sqledge_query, describe_sqledge_table)
- SQL migration tools (migrate_sql_query)
"""

from __future__ import annotations

from typing import Any

from src.tools.databricks_sql import describe_table, run_sql_query
from src.tools.sql_migration import migrate_sql_query
from src.tools.sqledge_sql import describe_sqledge_table, run_sqledge_query


def get_agent_tools() -> list[Any]:
    """Return tool instances compatible with LangChain tool calling."""
    return [
        run_sql_query,
        describe_table,
        run_sqledge_query,
        describe_sqledge_table,
        migrate_sql_query,
    ]

