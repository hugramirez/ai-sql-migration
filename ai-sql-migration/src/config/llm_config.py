"""Chat model factory."""

from __future__ import annotations

from langchain_anthropic import ChatAnthropic # type: ignore
from src.config.settings import Settings


def create_chat_model(settings: Settings):
    """Build the LangChain chat model configured for Anthropic (Claude)."""
    return ChatAnthropic(
        anthropic_api_key=settings.anthropic_api_key,
        model=settings.model_name,
        max_tokens=settings.max_tokens,
        temperature=settings.temperature,
    )

if __name__ == "__main__":
    settings = Settings.from_env()
    model = create_chat_model(settings)
    print(model)