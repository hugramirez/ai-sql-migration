"""Entry point: LangGraph Databricks agent via `AI SQL Migration`."""

from __future__ import annotations

import argparse
import os
import time
from pathlib import Path

from langchain_core.messages import AIMessage, HumanMessage, ToolMessage
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel
from rich.rule import Rule
from rich.table import Table
from rich.theme import Theme

from src.config import Settings, classify_query, judge_response
from src.graph.builder import build_agent
from src.observability import RunMetrics, collect_run_metrics
from src.tools.sql_migration import parse_migrated_sql_line

_MIGRATION_TOOL_NAMES = frozenset({"migrate_sql_query", "run_sql_query"})
_MIGRATION_TASK_PREFIX = "Migrate this T-SQL to Databricks"
_MIGRATION_SQL_MARK = "Here is the source SQL:\n\n"

_THEME = Theme(
    {
        "human": "bold cyan",
        "ai": "bold green",
        "tool": "bold yellow",
        "meta": "dim white",
    }
)
console = Console(theme=_THEME)


def _last_migrated_spark_sql(messages: list) -> str | None:
    """Return SQL from the last ``migrate_sql_query`` tool output (``MIGRATED_SQL:`` line)."""
    last: str | None = None
    for msg in messages:
        if not isinstance(msg, ToolMessage):
            continue
        name = getattr(msg, "name", None) or ""
        body = str(msg.content or "")
        if name == "migrate_sql_query" or "MIGRATED_SQL:" in body:
            last = body
    if not last:
        return None
    return parse_migrated_sql_line(last)


def _ai_migration_summary_block(content: str) -> str | None:
    """Return content to show if it looks like the migration + results report."""
    if not content or not content.strip():
        return None
    lower = content.lower()
    if "migration summary" in lower and "results" in lower:
        return content.strip()
    return None


def _human_display_body(content: str) -> str:
    """Short Human panel: full SQL is still sent to the model; UI stays minimal."""
    if content.strip().startswith(_MIGRATION_TASK_PREFIX) and _MIGRATION_SQL_MARK in content:
        idx = content.index(_MIGRATION_SQL_MARK) + len(_MIGRATION_SQL_MARK)
        n = len(content[idx:].strip())
        return (
            "[meta]T-SQL → Databricks migration[/meta]\n"
            f"Source SQL sent to the agent: [bold]{n}[/bold] characters "
            "(omitted here; original + migrated + results are in the AI panel below)."
        )
    if len(content) > 500:
        return (
            content[:500].rstrip()
            + f"\n\n[meta]({len(content)} chars total; truncated for display)[/meta]"
        )
    return content


def _print_messages(messages: list) -> None:
    console.print(Rule("[bold]Output[/bold]", style="bright_black"))

    human_body: str | None = None
    migrate_query_lens: list[int] = []
    run_sql_query_lens: list[int] = []
    last_migration_ai: str | None = None
    last_ai_response: str | None = None

    for msg in messages:
        if isinstance(msg, HumanMessage):
            human_body = str(msg.content)
        elif isinstance(msg, AIMessage):
            raw = msg.content
            if isinstance(raw, list):
                content = "\n".join(
                    block.get("text", "") for block in raw if block.get("type") == "text"
                ).strip()
            else:
                content = str(raw).strip()

            for tc in getattr(msg, "tool_calls", None) or []:
                tname = tc.get("name") or ""
                if tname == "migrate_sql_query":
                    q = (tc.get("args") or {}).get("query")
                    if isinstance(q, str):
                        migrate_query_lens.append(len(q))
                elif tname == "run_sql_query":
                    q = (tc.get("args") or {}).get("query")
                    if isinstance(q, str):
                        run_sql_query_lens.append(len(q))

            # Check for migration summary block first
            block = _ai_migration_summary_block(content)
            if block is not None:
                last_migration_ai = block
            # Otherwise, store the last AI response (only if no tool calls)
            elif not getattr(msg, "tool_calls", None):
                last_ai_response = content

    if human_body is not None:
        console.print(
            Panel(
                _human_display_body(human_body),
                title="[human]Human[/human]",
                border_style="cyan",
                padding=(0, 1),
            )
        )

    if migrate_query_lens:
        n = migrate_query_lens[-1]
        extra = f" [meta]({len(migrate_query_lens)} calls; last shown)[/meta]" if len(migrate_query_lens) > 1 else ""
        console.print(
            Panel(
                f"[meta]query[/meta]: {n} characters{extra}",
                title="[tool]Tool call → migrate_sql_query[/tool]",
                border_style="yellow",
                padding=(0, 1),
            )
        )

    if run_sql_query_lens:
        n = run_sql_query_lens[-1]
        extra = (
            f" [meta]({len(run_sql_query_lens) - 1} earlier run(s) omitted)[/meta]"
            if len(run_sql_query_lens) > 1
            else ""
        )
        console.print(
            Panel(
                f"[meta]query[/meta]: {n} characters{extra}",
                title="[tool]Tool call → run_sql_query[/tool]",
                border_style="yellow",
                padding=(0, 1),
            )
        )

    if last_migration_ai is not None:
        console.print(
            Panel(
                Markdown(last_migration_ai),
                title="[ai]AI — Migration Summary & Results[/ai]",
                border_style="green",
                padding=(0, 1),
            )
        )
    elif last_ai_response is not None:
        console.print(
            Panel(
                Markdown(last_ai_response),
                title="[ai]AI Response[/ai]",
                border_style="green",
                padding=(0, 1),
            )
        )

    console.print(Rule(style="bright_black"))


def _print_metrics_panel(metrics: RunMetrics) -> None:
    table = Table.grid(padding=(0, 2))
    table.add_column(style="meta")
    table.add_column(style="bold")

    table.add_row("Tier", metrics.tier)
    table.add_row("Model", f"{metrics.model} ({metrics.provider})")
    table.add_row("Latency", f"{metrics.latency_ms:,} ms")
    table.add_row("LLM calls", str(metrics.llm_calls))
    if metrics.tools_called:
        table.add_row("Tools used", ", ".join(metrics.tools_called))
    if metrics.input_tokens or metrics.output_tokens:
        table.add_row(
            "Tokens",
            f"{metrics.input_tokens:,} in / {metrics.output_tokens:,} out",
        )
    if metrics.estimated_cost_usd is not None:
        table.add_row("Est. cost", f"~${metrics.estimated_cost_usd:.6f} USD")
    if metrics.quality_score is not None:
        score_bar = "★" * metrics.quality_score + "☆" * (5 - metrics.quality_score)
        table.add_row("Quality", f"{score_bar}  {metrics.quality_score}/5  {metrics.quality_notes}")

    console.print(
        Panel(table, title="[meta]Run Metrics[/meta]", border_style="bright_black", padding=(0, 1))
    )


def _default_demo_query() -> str:
    return (
        "Migrate this SQL Edge query to Databricks using migrate_sql_query, then execute it with run_sql_query: "
        "SELECT TOP 5 ISNULL(first_name, 'unknown') AS first_name, ISNULL(last_name, 'unknown') AS last_name, "
        "GETDATE() AS migrated_at FROM localdb.dbo.dim_patient;"
    )


def _migration_task_prompt(sql_body: str) -> str:
    """Wrap raw T-SQL so the agent follows migrate_sql_query → run_sql_query."""
    return (
        "Migrate this T-SQL to Databricks using migrate_sql_query, then execute the migrated SQL with "
        "run_sql_query using exactly the statement from the MIGRATED_SQL: line (only adjust if Databricks "
        "returns a clear syntax error). Do not run exploratory SELECTs (e.g. LIMIT 5 on a single table). "
        "Use Unity Catalog paths as returned by migrate_sql_query (default localuc.gold.*). "
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
    parser.add_argument(
        "--write-migrated",
        type=Path,
        metavar="PATH.sql",
        help="After the run, write the last MIGRATED_SQL from migrate_sql_query to this file (UTF-8)",
    )
    args = parser.parse_args()

    settings = Settings.from_env()

    if args.sql_file is not None:
        path = args.sql_file.expanduser()
        if not path.is_file():
            raise SystemExit(f"Not a file: {path}")
        user_query = _migration_task_prompt(path.read_text(encoding="utf-8"))
    elif args.query:
        user_query = _migration_task_prompt(args.query)
    else:
        user_query = os.environ.get("USER_QUERY", _default_demo_query()).strip()

    console.print("[meta]Classifying query…[/meta]")
    tier = classify_query(settings, user_query)

    if settings.openrouter_api_key:
        _tier_model_map = {
            "simple": settings.openrouter_model_simple,
            "medium": settings.openrouter_model_medium,
            "complex": settings.openrouter_model_complex,
        }
        selected_model = _tier_model_map.get(tier, settings.openrouter_model_complex)
        console.print(
            f"[meta]Tier:[/meta] [bold]{tier}[/bold]  "
            f"[meta]Model:[/meta] [bold]{selected_model}[/bold]"
        )
    else:
        _anthropic_tier_map = {
            "simple": settings.anthropic_model_simple,
            "medium": settings.anthropic_model_medium,
            "complex": settings.anthropic_model_complex,
        }
        selected_model = _anthropic_tier_map.get(tier, settings.anthropic_model_complex)
        console.print(
            f"[meta]Tier:[/meta] [bold]{tier}[/bold]  "
            f"[meta]Model:[/meta] [bold]{selected_model}[/bold] [meta](Anthropic)[/meta]"
        )

    provider = "openrouter" if settings.openrouter_api_key else "anthropic"
    invoke_config = {"metadata": {"tier": tier, "model": selected_model, "provider": provider}}

    console.print("[meta]Starting agent…[/meta]")
    agent = build_agent(settings, tier=tier)

    messages = [HumanMessage(content=user_query)]
    _t0 = time.monotonic()
    result = agent.invoke({"messages": messages}, config=invoke_config)
    latency_ms = int((time.monotonic() - _t0) * 1000)

    _print_messages(result["messages"])

    # Collect and display run metrics
    metrics = collect_run_metrics(result, tier, selected_model, provider, latency_ms)

    if settings.quality_judge_enabled:
        last_ai = next(
            (str(m.content) for m in reversed(result["messages"]) if isinstance(m, AIMessage)),
            "",
        )
        judgment = judge_response(settings, user_query, last_ai)
        metrics.quality_score = judgment.get("score")
        metrics.quality_notes = judgment.get("notes", "")

    _print_metrics_panel(metrics)

    if args.write_migrated is not None:
        migrated = _last_migrated_spark_sql(result["messages"])
        out_path = args.write_migrated.expanduser()
        if not migrated:
            console.print("[meta]--write-migrated:[/meta] nothing to write (no MIGRATED_SQL: in tool output).")
        else:
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(migrated.strip() + "\n", encoding="utf-8")
            console.print(f"[meta]Wrote migrated SQL →[/meta] {out_path.resolve()}")


if __name__ == "__main__":
    main()
