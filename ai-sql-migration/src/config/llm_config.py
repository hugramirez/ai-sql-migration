"""Chat model factory — supports Anthropic (direct/tiered) and OpenRouter (tiered routing)."""

from __future__ import annotations

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


def classify_query(settings: Settings, query: str) -> str:
    """Classify query complexity using a cheap model from the configured provider.

    Returns 'simple', 'medium', or 'complex'.
    Falls back to 'complex' on any error or unexpected output.
    """
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
        return "complex"

    try:
        prompt = _CLASSIFIER_PROMPT.format(query=query)
        response = classifier_model.invoke([HumanMessage(content=prompt)])
        raw = str(response.content).strip().lower().split()[0]
        return raw if raw in _VALID_TIERS else "complex"
    except Exception:
        return "complex"


if __name__ == "__main__":
    settings = Settings.from_env()
    model = create_chat_model(settings)
    print(model)
