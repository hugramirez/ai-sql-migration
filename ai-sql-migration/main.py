"""Entry point: LangGraph Databricks agent via `AI SQL Migration`."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from langchain_core.messages import AIMessage, HumanMessage
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.rule import Rule
from rich.theme import Theme

from src.config import Settings
from src.graph.builder import build_agent

_DISPLAY_MAX_HUMAN_CHARS = 4000
_DISPLAY_MAX_TOOL_QUERY_CHARS = 280

_THEME = Theme(
    {
        "human": "bold cyan",
        "ai": "bold green",
        "tool": "bold yellow",
        "meta": "dim white",
    }
)
console = Console(theme=_THEME)


def _format_tool_arg_value(key: str, value: object) -> str:
    if key == "query" and isinstance(value, str) and len(value) > _DISPLAY_MAX_TOOL_QUERY_CHARS:
        head = value[:_DISPLAY_MAX_TOOL_QUERY_CHARS].rstrip() + "\n… "
        return f"{head}({len(value)} chars total; full text sent to warehouse)"
    if isinstance(value, str):
        return value
    return repr(value)


def _print_messages(messages: list) -> None:
    console.print(Rule("[bold]Agent conversation[/bold]", style="bright_black"))

    for msg in messages:
        if isinstance(msg, HumanMessage):
            body = str(msg.content)
            if len(body) > _DISPLAY_MAX_HUMAN_CHARS:
                body = (
                    body[:_DISPLAY_MAX_HUMAN_CHARS].rstrip()
                    + f"\n\n[meta]({len(str(msg.content))} chars total; full prompt was sent to the agent)[/meta]"
                )
            console.print(
                Panel(
                    body,
                    title="[human]Human[/human]",
                    border_style="cyan",
                    padding=(0, 1),
                )
            )

        elif isinstance(msg, AIMessage):
            raw = msg.content
            if isinstance(raw, list):
                content = "\n".join(
                    block.get("text", "") for block in raw if block.get("type") == "text"
                ).strip()
            else:
                content = str(raw).strip()

            tool_calls = getattr(msg, "tool_calls", [])
            if tool_calls:
                for tc in tool_calls:
                    args_text = "\n".join(
                        f"  [meta]{k}[/meta]: {_format_tool_arg_value(k, v)}"
                        for k, v in tc.get("args", {}).items()
                    )
                    console.print(
                        Panel(
                            args_text or "[meta](no args)[/meta]",
                            title=f"[tool]Tool call → {tc.get('name', '?')}[/tool]",
                            border_style="yellow",
                            padding=(0, 1),
                        )
                    )

            if content:
                console.print(
                    Panel(
                        Markdown(content),
                        title="[ai]AI[/ai]",
                        border_style="green",
                        padding=(0, 1),
                    )
                )

    console.print(Rule(style="bright_black"))


def _default_demo_query() -> str:
    return (
        "Migrate this SQL Edge query to Databricks using migrate_sql_query, then execute it with run_sql_query: "
        "SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, ISNULL(last_name, 'unknown') AS last_name, "
        "GETDATE() AS migrated_at FROM pharmacy_db.dbo.dim_patient;"
    )


def _migration_task_prompt(sql_body: str) -> str:
    """Wrap raw T-SQL so the agent follows migrate_sql_query → run_sql_query."""
    return (
        "Migrate this T-SQL to Databricks using migrate_sql_query, then execute the migrated SQL with "
        "run_sql_query using exactly the statement from the MIGRATED_SQL: line (only adjust if Databricks "
        "returns a clear syntax error). Do not run exploratory SELECTs (e.g. LIMIT 5 on a single table). "
        "Use Unity Catalog paths as returned by migrate_sql_query (default pharmacy.gold.*). "
        "Here is the source SQL:\n\n"
        f"{sql_body.strip()}"
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="LangGraph agent: T-SQL migration + Databricks SQL.")
    parser.add_argument(
        "--sql-file",
        type=Path,
        metavar="PATH",
        help="Read T-SQL from this file and ask the agent to migrate + run it (e.g. ../reports/patient_spending.sql)",
    )
    parser.add_argument(
        "-q",
        "--query",
        help="Inline T-SQL / instruction string (overrides USER_QUERY when set; ignored if --sql-file is set)",
    )
    args = parser.parse_args()

    settings = Settings.from_env()

    console.print(Rule("[bold]Initialising agent[/bold]", style="bright_black"))
    agent = build_agent(settings)

    if args.sql_file is not None:
        path = args.sql_file.expanduser()
        if not path.is_file():
            raise SystemExit(f"Not a file: {path}")
        user_query = _migration_task_prompt(path.read_text(encoding="utf-8"))
    elif args.query:
        user_query = _migration_task_prompt(args.query)
    else:
        user_query = os.environ.get("USER_QUERY", _default_demo_query()).strip()

    messages = [HumanMessage(content=user_query)]
    result = agent.invoke({"messages": messages})
    _print_messages(result["messages"])


if __name__ == "__main__":
    main()
