"""Chat model factory — supports Anthropic (direct/tiered) and OpenRouter (tiered routing)."""

from __future__ import annotations

import json

from langchain_anthropic import ChatAnthropic  # type: ignore
from langchain_openai import ChatOpenAI  # type: ignore
from langchain_core.messages import HumanMessage

from src.config.settings import Settings

_OPENROUTER_BASE_URL = "https://openrouter.ai/api/v1"
_VALID_TIERS = frozenset({"simple", "medium", "complex"})

_CLASSIFIER_PROMPT = """\
You are a SQL query complexity classifier.
Classify the following user query into exactly one tier:

- simple: Basic SELECT on 1 table, describe table schema, or simple data lookups. No migration needed.
- medium: JOINs, GROUP BY, aggregations, multi-condition filters. May involve migration.
- complex: Full T-SQL to Spark SQL migration, subqueries, multi-table analytics, or long queries.

Reply with ONLY one word: simple, medium, or complex.

Query: {query}"""


def create_chat_model(settings: Settings):
    """Build the LangChain chat model configured for Anthropic (uses settings.model_name)."""
    return ChatAnthropic(
        anthropic_api_key=settings.anthropic_api_key,
        model=settings.model_name,
        max_tokens=settings.max_tokens,
        temperature=settings.temperature,
    )


def create_anthropic_model(settings: Settings, tier: str = "complex"):
    """Build a tier-aware ChatAnthropic model."""
    tier_map = {
        "simple": settings.anthropic_model_simple,
        "medium": settings.anthropic_model_medium,
        "complex": settings.anthropic_model_complex,
    }
    model_name = tier_map.get(tier, settings.anthropic_model_complex)
    return ChatAnthropic(
        anthropic_api_key=settings.anthropic_api_key,
        model=model_name,
        max_tokens=settings.max_tokens,
        temperature=settings.temperature,
    )


def create_openrouter_model(settings: Settings, tier: str = "complex"):
    """Build a LangChain chat model backed by OpenRouter (OpenAI-compatible API)."""
    tier_map = {
        "simple": settings.openrouter_model_simple,
        "medium": settings.openrouter_model_medium,
        "complex": settings.openrouter_model_complex,
    }
    model_name = tier_map.get(tier, settings.openrouter_model_complex)
    return ChatOpenAI(
        api_key=settings.openrouter_api_key,
        base_url=_OPENROUTER_BASE_URL,
        model=model_name,
        max_tokens=settings.max_tokens,
        temperature=settings.temperature,
    )


class ClassifierResult:
    """Tier decision plus token usage from the classifier call."""
    __slots__ = ("tier", "input_tokens", "output_tokens")

    def __init__(self, tier: str, input_tokens: int = 0, output_tokens: int = 0):
        self.tier = tier
        self.input_tokens = input_tokens
        self.output_tokens = output_tokens

    def __str__(self) -> str:
        return self.tier


def classify_query(settings: Settings, query: str) -> ClassifierResult:
    """Classify query complexity using a cheap model from the configured provider.

    Returns a ClassifierResult with tier ('simple'/'medium'/'complex') and token usage.
    Falls back to tier='complex' with zero tokens on any error.
    """
    _fallback = ClassifierResult("complex")

    if settings.openrouter_api_key:
        classifier_model = ChatOpenAI(
            api_key=settings.openrouter_api_key,
            base_url=_OPENROUTER_BASE_URL,
            model=settings.openrouter_model_classifier,
            max_tokens=16,
            temperature=0.0,
        )
    elif settings.anthropic_api_key:
        classifier_model = ChatAnthropic(
            anthropic_api_key=settings.anthropic_api_key,
            model=settings.anthropic_model_classifier,
            max_tokens=16,
            temperature=0.0,
        )
    else:
        return _fallback

    try:
        prompt = _CLASSIFIER_PROMPT.format(query=query)
        response = classifier_model.invoke([HumanMessage(content=prompt)])
        raw = str(response.content).strip().lower().split()[0]
        tier = raw if raw in _VALID_TIERS else "complex"
        meta = getattr(response, "usage_metadata", None) or {}
        return ClassifierResult(
            tier=tier,
            input_tokens=meta.get("input_tokens", 0),
            output_tokens=meta.get("output_tokens", 0),
        )
    except Exception:
        return _fallback


_JUDGE_PROMPT = """\
You are a QA evaluator for a SQL data agent. Evaluate the agent's response quality.

User query: {query}

Agent response:
{response}

Rate the response from 1 to 5:
5 = Excellent: complete, well-formatted, all requirements met
4 = Good: complete with minor issues or omissions
3 = Adequate: answers the question but missing relevant detail
2 = Below average: partial answer or significant formatting issues
1 = Poor: wrong answer, missing key information, or errors

Reply with ONLY valid JSON (no markdown, no extra text):
{{"score": <1-5>, "notes": "<one sentence explanation>"}}"""


def judge_response(settings: Settings, user_query: str, agent_response: str) -> dict:
    """Evaluate agent response quality using a cheap model.

    Returns {"score": int (1-5), "notes": str}.
    Falls back to {"score": None, "notes": "judge unavailable"} on any error.
    """
    _fallback = {"score": None, "notes": "judge unavailable"}
    if not agent_response.strip():
        return _fallback

    if settings.openrouter_api_key:
        judge_model = ChatOpenAI(
            api_key=settings.openrouter_api_key,
            base_url=_OPENROUTER_BASE_URL,
            model=settings.openrouter_model_classifier,
            max_tokens=128,
            temperature=0.0,
        )
    elif settings.anthropic_api_key:
        judge_model = ChatAnthropic(
            anthropic_api_key=settings.anthropic_api_key,
            model=settings.anthropic_model_classifier,
            max_tokens=128,
            temperature=0.0,
        )
    else:
        return _fallback

    try:
        prompt = _JUDGE_PROMPT.format(
            query=user_query[:1000],
            response=agent_response[:3000],
        )
        response = judge_model.invoke([HumanMessage(content=prompt)])
        raw = str(response.content).strip()
        # strip possible markdown code fences
        if raw.startswith("```"):
            raw = raw.split("```")[1].lstrip("json").strip()
        data = json.loads(raw)
        score = int(data.get("score", 0))
        if score not in range(1, 6):
            return _fallback
        return {"score": score, "notes": str(data.get("notes", ""))}
    except Exception:
        return _fallback


if __name__ == "__main__":
    settings = Settings.from_env()
    model = create_chat_model(settings)
    print(model)
