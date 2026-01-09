"""
ShaneBrain Core - Main Agent
=============================

The central ShaneBrain agent that integrates all components.

Usage:
    from langchain_chains.shanebrain_agent import ShaneBrainAgent
    agent = ShaneBrainAgent.from_config()
    response = agent.chat("Tell me about Shane's values")

Author: Shane Brazelton
"""

import os
import sys
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import Enum
import uuid

sys.path.insert(0, str(Path(__file__).parent))

try:
    from crisis_detection_chain import CrisisDetectionChain, CrisisLevel
    CRISIS_AVAILABLE = True
except ImportError:
    CrisisDetectionChain = None
    CrisisLevel = None
    CRISIS_AVAILABLE = False

try:
    from qa_retrieval_chain import QARetrievalChain
    QA_AVAILABLE = True
except ImportError:
    QARetrievalChain = None
    QA_AVAILABLE = False

try:
    from code_generation_chain import CodeGenerationChain
    CODE_AVAILABLE = True
except ImportError:
    CodeGenerationChain = None
    CODE_AVAILABLE = False

try:
    from langchain.memory import ConversationBufferWindowMemory
    from langchain.prompts import PromptTemplate
    from langchain.chains import LLMChain
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False

try:
    import weaviate
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False

try:
    from pymongo import MongoClient
    MONGODB_AVAILABLE = True
except ImportError:
    MONGODB_AVAILABLE = False


class AgentMode(Enum):
    CHAT = "chat"
    MEMORY = "memory"
    WELLNESS = "wellness"
    SECURITY = "security"
    DISPATCH = "dispatch"
    CODE = "code"


SYSTEM_PROMPTS = {
    AgentMode.CHAT: "You are ShaneBrain, Shane Brazelton's AI assistant. Be warm and helpful.",
    AgentMode.MEMORY: "You are the ShaneBrain Legacy interface. Help family connect with memories.",
    AgentMode.WELLNESS: "You are Angel Cloud. SAFETY FIRST - watch for crisis indicators.",
    AgentMode.SECURITY: "You are Pulsar AI, a blockchain security assistant.",
    AgentMode.DISPATCH: "You are LogiBot, a dispatch automation assistant.",
    AgentMode.CODE: "You are a code generation assistant."
}


@dataclass
class AgentContext:
    session_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    user_id: Optional[str] = None
    mode: AgentMode = AgentMode.CHAT
    project: Optional[str] = None
    planning_files: List[str] = field(default_factory=list)
    current_task: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class AgentResponse:
    message: str
    mode: AgentMode
    crisis_detected: bool = False
    crisis_level: Optional[str] = None
    sources: List[Dict] = field(default_factory=list)
    suggestions: List[str] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "message": self.message,
            "mode": self.mode.value,
            "crisis_detected": self.crisis_detected,
            "crisis_level": self.crisis_level,
            "sources_count": len(self.sources),
            "timestamp": self.timestamp.isoformat(),
        }


class ShaneBrainAgent:
    """Main ShaneBrain agent integrating all components."""

    def __init__(
        self,
        llm=None,
        weaviate_client=None,
        mongodb_client=None,
        planning_root: Optional[Path] = None,
        default_mode: AgentMode = AgentMode.CHAT,
        enable_crisis_detection: bool = True,
        memory_window: int = 10,
    ):
        self.llm = llm
        self.weaviate_client = weaviate_client
        self.mongodb_client = mongodb_client
        self.planning_root = planning_root or Path(
            os.environ.get("PLANNING_ROOT", "/mnt/8TB/ShaneBrain-Core/planning-system")
        )
        self.default_mode = default_mode
        self.enable_crisis_detection = enable_crisis_detection
        self.context = AgentContext(mode=default_mode)
        self._conversation_history = []

        if LANGCHAIN_AVAILABLE:
            self.memory = ConversationBufferWindowMemory(
                k=memory_window, memory_key="chat_history", return_messages=False
            )
        else:
            self.memory = None

        self._init_chains()

    def _init_chains(self) -> None:
        if CrisisDetectionChain and self.enable_crisis_detection:
            self.crisis_chain = CrisisDetectionChain(llm=self.llm)
        else:
            self.crisis_chain = None

        if QARetrievalChain:
            self.qa_chain = QARetrievalChain(
                llm=self.llm, weaviate_client=self.weaviate_client
            )
        else:
            self.qa_chain = None

        if CodeGenerationChain:
            self.code_chain = CodeGenerationChain(llm=self.llm)
        else:
            self.code_chain = None

    def _load_planning_context(self) -> str:
        context_parts = []
        task_plan = self.planning_root / "active-projects" / "task_plan.md"
        if task_plan.exists():
            try:
                context_parts.append(task_plan.read_text()[:2000])
            except Exception:
                pass
        return "\n\n".join(context_parts) if context_parts else ""

    def _get_chat_history(self) -> str:
        if self.memory:
            try:
                return self.memory.load_memory_variables({}).get("chat_history", "")
            except Exception:
                return ""
        return "\n".join(self._conversation_history[-10:])

    def _save_to_memory(self, user_input: str, response: str) -> None:
        if self.memory:
            try:
                self.memory.save_context({"input": user_input}, {"output": response})
            except Exception:
                pass
        self._conversation_history.append(f"User: {user_input}")
        self._conversation_history.append(f"Assistant: {response}")

    def _check_crisis(self, message: str):
        if not self.crisis_chain:
            return None
        try:
            return self.crisis_chain.detect(message)
        except Exception:
            return None

    def _generate_response(self, user_input: str, mode: AgentMode, context: str, history: str) -> str:
        system_prompt = SYSTEM_PROMPTS.get(mode, SYSTEM_PROMPTS[AgentMode.CHAT])

        if self.llm and LANGCHAIN_AVAILABLE:
            try:
                prompt = PromptTemplate(
                    input_variables=["system", "context", "history", "input"],
                    template="{system}\n\nContext: {context}\n\nHistory: {history}\n\nUser: {input}\n\nAssistant:"
                )
                chain = LLMChain(llm=self.llm, prompt=prompt)
                return chain.run(system=system_prompt, context=context, history=history, input=user_input)
            except Exception as e:
                return f"I'm here to help. (LLM error: {e})"

        return f"Hello! I'm ShaneBrain. LLM not configured - please set up local Llama model."

    def chat(self, message: str, mode: Optional[AgentMode] = None) -> AgentResponse:
        """Main chat interface."""
        mode = mode or self.context.mode

        # Crisis check for wellness mode
        crisis_result = None
        if mode == AgentMode.WELLNESS or self.enable_crisis_detection:
            crisis_result = self._check_crisis(message)

        # Handle crisis
        if crisis_result and crisis_result.crisis_level and crisis_result.crisis_level.value in ["high", "critical"]:
            return AgentResponse(
                message=crisis_result.response,
                mode=mode,
                crisis_detected=True,
                crisis_level=crisis_result.crisis_level.value,
                metadata={"crisis_score": crisis_result.crisis_score}
            )

        # Load context and history
        planning_context = self._load_planning_context()
        chat_history = self._get_chat_history()

        # Generate response
        response_text = self._generate_response(message, mode, planning_context, chat_history)

        # Save to memory
        self._save_to_memory(message, response_text)

        # Log to MongoDB
        if self.mongodb_client:
            try:
                self.mongodb_client.conversations.insert_one({
                    "session_id": self.context.session_id,
                    "message": message[:100],  # Truncate for privacy
                    "mode": mode.value,
                    "timestamp": datetime.now()
                })
            except Exception:
                pass

        return AgentResponse(
            message=response_text,
            mode=mode,
            crisis_detected=crisis_result is not None and crisis_result.crisis_score > 0.3 if crisis_result else False,
            crisis_level=crisis_result.crisis_level.value if crisis_result and crisis_result.crisis_level else None,
        )

    def set_mode(self, mode: AgentMode) -> None:
        """Change agent mode."""
        self.context.mode = mode

    def clear_memory(self) -> None:
        """Clear conversation memory."""
        if self.memory:
            self.memory.clear()
        self._conversation_history = []

    def load_planning_files(self, files: List[str]) -> None:
        """Load specific planning files for context."""
        self.context.planning_files = files

    @classmethod
    def from_config(
        cls,
        config_path: Optional[str] = None,
        weaviate_host: str = "localhost",
        weaviate_port: int = 8080,
        mongodb_uri: Optional[str] = None,
    ) -> "ShaneBrainAgent":
        """Create agent from configuration."""
        weaviate_client = None
        mongodb_client = None

        # Connect to Weaviate
        if WEAVIATE_AVAILABLE:
            try:
                weaviate_client = weaviate.Client(f"http://{weaviate_host}:{weaviate_port}")
                if not weaviate_client.is_ready():
                    weaviate_client = None
            except Exception:
                pass

        # Connect to MongoDB
        if MONGODB_AVAILABLE and mongodb_uri:
            try:
                client = MongoClient(mongodb_uri, serverSelectionTimeoutMS=5000)
                mongodb_client = client.shanebrain_db
            except Exception:
                pass

        return cls(
            weaviate_client=weaviate_client,
            mongodb_client=mongodb_client,
        )


# =============================================================================
# EXAMPLE USAGE
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("ShaneBrain Agent - Demo")
    print("=" * 60)

    # Create agent without external dependencies
    agent = ShaneBrainAgent(enable_crisis_detection=True)

    # Test messages
    test_messages = [
        ("Hello! How are you?", AgentMode.CHAT),
        ("Tell me about Shane's values", AgentMode.MEMORY),
        ("I've been feeling down lately", AgentMode.WELLNESS),
        ("Analyze this smart contract for vulnerabilities", AgentMode.SECURITY),
    ]

    print("\nTesting agent modes:\n")

    for message, mode in test_messages:
        agent.set_mode(mode)
        response = agent.chat(message)
        print(f"Mode: {mode.value}")
        print(f"User: {message}")
        print(f"Response: {response.message[:100]}...")
        print(f"Crisis: {response.crisis_detected}")
        print()

    print("=" * 60)
    print("To use with full capabilities, connect LLM and Weaviate.")
    print("=" * 60)
