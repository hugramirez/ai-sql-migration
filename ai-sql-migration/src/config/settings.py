"""Application settings loaded from environment variables."""

from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()

DEFAULT_SYSTEM_PROMPT = (
    "You are a helpful assistant that can query Databricks data sources and Azure SQL Edge."
)

@dataclass(frozen=True)
class Settings:
    """Runtime configuration for the LangGraph agent."""

    model_name: str = "claude-haiku-4-5-20251001"
    max_tokens: int = 1024
    temperature: float = 0.0
    system_prompt: str = DEFAULT_SYSTEM_PROMPT
    anthropic_api_key: str = ""
    databricks_host: str = ""
    databricks_token: str = ""
    databricks_warehouse_id: str = ""
    uc_catalog: str = ""
    uc_schema: str = ""
    sqledge_host: str = "localhost"
    sqledge_port: int = 1433
    sqledge_database: str = ""
    sqledge_user: str = ""
    sqledge_password: str = ""


    @classmethod
    def from_env(cls) -> Settings:
        key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
        if not key:
            raise SystemExit(
                "ANTHROPIC_API_KEY is not set. Claude requires an Anthropic API key.\n\n"
                "Example:\n"
                "  export ANTHROPIC_API_KEY='sk-ant-api03-...'\n"
                "  uv run python main.py\n"
            )

        return cls(
            anthropic_api_key=key,
            databricks_host=os.environ.get("DATABRICKS_HOST", "").strip(),
            databricks_token=os.environ.get("DATABRICKS_TOKEN", "").strip(),
            databricks_warehouse_id=os.environ.get("DATABRICKS_WAREHOUSE_ID", "").strip(),
            uc_catalog=os.environ.get("UC_CATALOG", "").strip(),
            uc_schema=os.environ.get("UC_SCHEMA", "").strip(),
            sqledge_host=os.environ.get("SQLEDGE_HOST", "localhost").strip(),
            sqledge_port=int(os.environ.get("SQLEDGE_PORT", "1433")),
            sqledge_database=os.environ.get("SQLEDGE_DATABASE", "sqledge_dev").strip(),
            sqledge_user=os.environ.get("SQLEDGE_USER", "").strip(),
            sqledge_password=os.environ.get("SQLEDGE_PASSWORD", "").strip(),
        )


if __name__ == "__main__":
    settings = Settings.from_env()
    print(settings)