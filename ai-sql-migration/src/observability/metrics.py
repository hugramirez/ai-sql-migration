"""Run metrics: latency, token usage, cost estimation, and quality score."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from langchain_core.messages import AIMessage

# Price table: (input_per_1M_usd, output_per_1M_usd)
# Sources: Anthropic pricing page + OpenRouter model cards (approx. 2025-05)
_MODEL_PRICES: dict[str, tuple[float, float]] = {
    # Anthropic
    "claude-haiku-4-5-20251001": (0.80, 4.00),
    "claude-haiku-3-5-20251001": (0.80, 4.00),
    "claude-sonnet-4-5": (3.00, 15.00),
    "claude-sonnet-4-5-20250514": (3.00, 15.00),
    "claude-opus-4-8": (15.00, 75.00),
    "claude-opus-4-8-20250514": (15.00, 75.00),
    # OpenRouter — same underlying Anthropic models (via proxy)
    "anthropic/claude-haiku-4-5": (0.80, 4.00),
    "anthropic/claude-sonnet-4-5": (3.00, 15.00),
    "anthropic/claude-opus-4-8": (15.00, 75.00),
    # OpenRouter — free/open models
    "meta-llama/llama-3.1-8b-instruct:free": (0.0, 0.0),
    "meta-llama/llama-3.1-70b-instruct": (0.10, 0.28),
    "mistralai/mixtral-8x7b-instruct": (0.24, 0.24),
    "mistralai/mistral-7b-instruct": (0.06, 0.06),
}


@dataclass
class RunMetrics:
    tier: str = "complex"
    model: str = ""
    provider: str = ""          # "anthropic" | "openrouter"
    latency_ms: int = 0
    llm_calls: int = 0
    tools_called: list[str] = field(default_factory=list)
    input_tokens: int = 0
    output_tokens: int = 0
    estimated_cost_usd: float | None = None
    quality_score: int | None = None   # 1–5
    quality_notes: str = ""


def _extract_token_counts(messages: list[Any]) -> tuple[int, int]:
    """Sum input/output tokens from all AIMessage usage_metadata."""
    total_in = total_out = 0
    for msg in messages:
        if not isinstance(msg, AIMessage):
            continue
        meta = getattr(msg, "usage_metadata", None)
        if not meta:
            continue
        total_in += meta.get("input_tokens", 0)
        total_out += meta.get("output_tokens", 0)
    return total_in, total_out


def _extract_tools_called(messages: list[Any]) -> list[str]:
    """Collect unique tool names called across all AIMessages."""
    seen: list[str] = []
    for msg in messages:
        if not isinstance(msg, AIMessage):
            continue
        for tc in getattr(msg, "tool_calls", None) or []:
            name = tc.get("name", "")
            if name and name not in seen:
                seen.append(name)
    return seen


def estimate_cost(model: str, input_tokens: int, output_tokens: int) -> float | None:
    """Return estimated USD cost for a run, or None if the model is unknown."""
    prices = _MODEL_PRICES.get(model)
    if prices is None:
        return None
    cost = (input_tokens / 1_000_000) * prices[0] + (output_tokens / 1_000_000) * prices[1]
    return round(cost, 6)


def collect_run_metrics(
    result: dict[str, Any],
    tier: str,
    model: str,
    provider: str,
    latency_ms: int,
) -> RunMetrics:
    """Build a RunMetrics from a completed agent.invoke() result."""
    messages = result.get("messages", [])
    llm_calls = result.get("llm_calls", 0)
    input_tokens, output_tokens = _extract_token_counts(messages)
    tools_called = _extract_tools_called(messages)

    return RunMetrics(
        tier=tier,
        model=model,
        provider=provider,
        latency_ms=latency_ms,
        llm_calls=llm_calls,
        tools_called=tools_called,
        input_tokens=input_tokens,
        output_tokens=output_tokens,
        estimated_cost_usd=estimate_cost(model, input_tokens, output_tokens),
    )
