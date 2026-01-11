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

# LangChain imports - try new API first, fall back to legacy
LANGCHAIN_AVAILABLE = False
try:
    from langchain_core.prompts import PromptTemplate
    LANGCHAIN_AVAILABLE = True
except ImportError:
    try:
        from langchain.prompts import PromptTemplate
        LANGCHAIN_AVAILABLE = True
    except ImportError:
        PromptTemplate = None

try:
    from langchain_ollama import OllamaLLM
    OLLAMA_LANGCHAIN_AVAILABLE = True
except ImportError:
    OllamaLLM = None
    OLLAMA_LANGCHAIN_AVAILABLE = False

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

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass


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
    AgentMode.WELLNESS: "You are Angel Cloud, a compassionate mental wellness companion. SAFETY FIRST - watch for crisis indicators. Be warm, supportive, and non-judgmental.",
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
            os.environ.get("PLANNING_ROOT", "D:/Angel_Cloud/shanebrain-core/planning-system")
        )
        self.default_mode = default_mode
        self.enable_crisis_detection = enable_crisis_detection
        self.context = AgentContext(mode=default_mode)
        self._conversation_history = []
        self.memory = None  # Simplified - just use _conversation_history

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
        return "\n".join(self._conversation_history[-10:])

    def _save_to_memory(self, user_input: str, response: str) -> None:
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

        if self.llm:
            try:
                # Build prompt for direct LLM invocation
                ctx_text = context if context else "No additional context."
                hist_text = history if history else "This is the start of our conversation."

                full_prompt = f"""{system_prompt}

Context: {ctx_text}

Conversation History:
{hist_text}

User: {user_input}
Assistant:"""
                # Invoke the LLM directly
                result = self.llm.invoke(full_prompt)
                return result.strip() if isinstance(result, str) else str(result)
            except Exception as e:
                return f"I'm here to help. (Error: {e})"

        return "Hello! I'm ShaneBrain. LLM not configured - please set up Ollama with: ollama pull llama3.2:1b"

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
                    "message": message[:100],
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
        ollama_host: str = "http://localhost:11434",
        ollama_model: str = "llama3.2:1b",
    ) -> "ShaneBrainAgent":
        """Create agent from configuration."""
        llm = None
        weaviate_client = None
        mongodb_client = None

        # Load from environment if available
        ollama_host = os.environ.get("OLLAMA_HOST", ollama_host)
        ollama_model = os.environ.get("OLLAMA_MODEL", ollama_model)
        weaviate_host = os.environ.get("WEAVIATE_HOST", weaviate_host)
        weaviate_port = int(os.environ.get("WEAVIATE_PORT", weaviate_port))

        # Connect to Ollama LLM
        if OLLAMA_LANGCHAIN_AVAILABLE:
            try:
                llm = OllamaLLM(
                    model=ollama_model,
                    base_url=ollama_host,
                    temperature=0.7,
                )
                # Test connection
                llm.invoke("test")
                print(f"[OK] Connected to Ollama ({ollama_model})")
            except Exception as e:
                print(f"[WARN] Ollama connection failed: {e}")
                llm = None

        # Connect to Weaviate (v4 API)
        if WEAVIATE_AVAILABLE:
            try:
                weaviate_client = weaviate.connect_to_local(
                    host=weaviate_host,
                    port=weaviate_port,
                )
                if weaviate_client.is_ready():
                    print(f"[OK] Connected to Weaviate ({weaviate_host}:{weaviate_port})")
                else:
                    weaviate_client.close()
                    weaviate_client = None
            except Exception as e:
                print(f"[WARN] Weaviate connection failed: {e}")
                weaviate_client = None

        # Connect to MongoDB
        if MONGODB_AVAILABLE and mongodb_uri:
            try:
                client = MongoClient(mongodb_uri, serverSelectionTimeoutMS=5000)
                mongodb_client = client.shanebrain_db
                print(f"[OK] Connected to MongoDB")
            except Exception:
                pass

        return cls(
            llm=llm,
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
    print()

    # Create agent from configuration (connects to Ollama, Weaviate)
    print("Initializing agent...")
    agent = ShaneBrainAgent.from_config()
    print()

    # Show status
    print("Component Status:")
    print(f"  LLM: {'Connected' if agent.llm else 'Not available'}")
    print(f"  Weaviate: {'Connected' if agent.weaviate_client else 'Not available'}")
    print(f"  Crisis Detection: {'Enabled' if agent.crisis_chain else 'Disabled'}")
    print()

    # Test messages
    test_messages = [
        ("Hello! How are you?", AgentMode.CHAT),
        ("Tell me about the importance of family", AgentMode.MEMORY),
    ]

    print("Testing agent responses:\n")

    for message, mode in test_messages:
        agent.set_mode(mode)
        response = agent.chat(message)
        print(f"[{mode.value.upper()}] User: {message}")
        print(f"Response: {response.message[:300]}...")
        print()

    print("=" * 60)
    print("Agent demo complete. Run angel_cloud_cli.py for full interface.")
    print("=" * 60)
