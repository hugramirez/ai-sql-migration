"""Graph state — same shape as the LangGraph quickstart."""

from __future__ import annotations

import operator
from typing import Annotated

from langchain_core.messages import BaseMessage
from typing_extensions import TypedDict


class MessagesState(TypedDict):
    messages: Annotated[list[BaseMessage], operator.add]
    llm_calls: int
