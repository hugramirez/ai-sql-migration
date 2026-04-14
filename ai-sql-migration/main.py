"""Entry point: LangGraph Databricks agent via `AI SQL Migration`."""

from __future__ import annotations

import os

from langchain_core.messages import AIMessage, HumanMessage
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.rule import Rule
from rich.theme import Theme

from src.config import Settings
from src.graph.builder import build_agent

_THEME = Theme(
    {
        "human": "bold cyan",
        "ai": "bold green",
        "tool": "bold yellow",
        "meta": "dim white",
    }
)
console = Console(theme=_THEME)


def _print_messages(messages: list) -> None:
    console.print(Rule("[bold]Agent conversation[/bold]", style="bright_black"))

    for msg in messages:
        if isinstance(msg, HumanMessage):
            console.print(
                Panel(
                    str(msg.content),
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
                        f"  [meta]{k}[/meta]: {v}" for k, v in tc.get("args", {}).items()
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


def main() -> None:
    settings = Settings.from_env()

    console.print(Rule("[bold]Initialising agent[/bold]", style="bright_black"))
    agent = build_agent(settings)

    user_query = os.environ.get(
        "USER_QUERY",
        "Use run_sql_query to list 5 rows from workspace.default.summary_employee_assignments. "
        "If the source is Azure SQL Edge, use run_sqledge_query instead.",
    ).strip()

    console.print(Panel(user_query, title="[human]Query[/human]", border_style="cyan", padding=(0, 1)))

    messages = [HumanMessage(content=user_query)]
    result = agent.invoke({"messages": messages})
    _print_messages(result["messages"])


if __name__ == "__main__":
    main()
