"""
ShaneBrain Core - QA Retrieval Chain
=====================================

LangChain-based Question Answering with Retrieval Augmented Generation (RAG).

This chain:
- Retrieves relevant documents from Weaviate vector store
- Uses local Llama model for answer generation
- Maintains conversation context
- Works completely offline

Usage:
    from langchain_chains.qa_retrieval_chain import QARetrievalChain

    chain = QARetrievalChain(weaviate_client=client, llm=llm)
    answer = chain.ask("What are Shane's core values?")
    print(answer.response)

Author: Shane Brazelton
"""

import os
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any, Tuple
from enum import Enum

# LangChain imports
try:
    from langchain.prompts import PromptTemplate
    from langchain.chains import LLMChain
    from langchain.memory import ConversationBufferWindowMemory
    from langchain.schema import Document
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("Warning: LangChain not installed. Install with: pip install langchain")

# Weaviate imports
try:
    import weaviate
    WEAVIATE_AVAILABLE = True
except ImportError:
    WEAVIATE_AVAILABLE = False
    print("Warning: Weaviate client not installed. Install with: pip install weaviate-client")


# =============================================================================
# CONFIGURATION
# =============================================================================

# Default prompt templates for different use cases
QA_PROMPT_TEMPLATE = """You are Shane's digital assistant, helping to answer questions using Shane's memories, values, and knowledge.

Context from Shane's memories:
{context}

Previous conversation:
{chat_history}

User's question: {question}

Provide a helpful, accurate answer based on the context above. If the context doesn't contain relevant information, acknowledge that and provide what guidance you can. Always be warm, authentic, and reflect Shane's values of honesty, family-first, and helping others.

Answer:"""

MEMORY_SEARCH_TEMPLATE = """Based on this question, generate a search query to find relevant memories:

Question: {question}

Search query (keywords and concepts):"""


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class RetrievedDocument:
    """A document retrieved from the vector store"""
    content: str
    title: str = ""
    category: str = ""
    relevance_score: float = 0.0
    metadata: Dict[str, Any] = field(default_factory=dict)
    weaviate_id: str = ""

    def to_context_string(self) -> str:
        """Format for inclusion in prompt context"""
        parts = []
        if self.title:
            parts.append(f"**{self.title}**")
        if self.category:
            parts.append(f"[{self.category}]")
        parts.append(self.content)
        return "\n".join(parts)


@dataclass
class QAResult:
    """Result of a QA query"""
    question: str
    answer: str
    sources: List[RetrievedDocument] = field(default_factory=list)
    confidence: float = 0.0
    tokens_used: int = 0
    retrieval_time_ms: float = 0.0
    generation_time_ms: float = 0.0
    timestamp: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for storage"""
        return {
            "question": self.question,
            "answer": self.answer,
            "source_count": len(self.sources),
            "confidence": self.confidence,
            "tokens_used": self.tokens_used,
            "retrieval_time_ms": self.retrieval_time_ms,
            "generation_time_ms": self.generation_time_ms,
            "timestamp": self.timestamp.isoformat(),
        }


# =============================================================================
# QA RETRIEVAL CHAIN
# =============================================================================

class QARetrievalChain:
    """
    Question Answering chain with Retrieval Augmented Generation.

    Uses Weaviate for semantic search and local Llama for generation.
    Works completely offline on your 8TB drive.
    """

    def __init__(
        self,
        llm=None,
        weaviate_client=None,
        weaviate_class: str = "ShanebrainMemory",
        mongodb_client=None,
        max_context_docs: int = 5,
        memory_window: int = 5,
        confidence_threshold: float = 0.7,
    ):
        """
        Initialize the QA chain.

        Args:
            llm: LangChain LLM instance (required for generation)
            weaviate_client: Weaviate client for retrieval
            weaviate_class: Weaviate class to search
            mongodb_client: MongoDB client for logging
            max_context_docs: Maximum documents to include in context
            memory_window: Number of conversation turns to remember
            confidence_threshold: Minimum similarity for relevant docs
        """
        self.llm = llm
        self.weaviate_client = weaviate_client
        self.weaviate_class = weaviate_class
        self.mongodb_client = mongodb_client
        self.max_context_docs = max_context_docs
        self.confidence_threshold = confidence_threshold

        # Initialize conversation memory
        if LANGCHAIN_AVAILABLE:
            self.memory = ConversationBufferWindowMemory(
                k=memory_window,
                memory_key="chat_history",
                return_messages=False
            )
        else:
            self.memory = None

        # Initialize LLM chain
        self._init_chains()

    def _init_chains(self) -> None:
        """Initialize LangChain chains"""
        if not LANGCHAIN_AVAILABLE:
            return

        # Main QA chain
        self.qa_prompt = PromptTemplate(
            input_variables=["context", "chat_history", "question"],
            template=QA_PROMPT_TEMPLATE
        )

        if self.llm:
            self.qa_chain = LLMChain(
                llm=self.llm,
                prompt=self.qa_prompt,
                verbose=False
            )

    def _retrieve_documents(
        self,
        query: str,
        filters: Optional[Dict] = None
    ) -> List[RetrievedDocument]:
        """
        Retrieve relevant documents from Weaviate.

        Args:
            query: Search query
            filters: Optional Weaviate filters

        Returns:
            List of retrieved documents
        """
        if not self.weaviate_client or not WEAVIATE_AVAILABLE:
            return []

        try:
            # Build Weaviate query
            query_builder = (
                self.weaviate_client.query
                .get(self.weaviate_class, [
                    "title", "content", "category", "themes",
                    "lessonLearned", "accessLevel"
                ])
                .with_near_text({"concepts": [query]})
                .with_limit(self.max_context_docs)
                .with_additional(["certainty", "id"])
            )

            # Add filters if provided
            if filters:
                query_builder = query_builder.with_where(filters)

            # Execute query
            result = query_builder.do()

            # Parse results
            documents = []
            if result and "data" in result and "Get" in result["data"]:
                items = result["data"]["Get"].get(self.weaviate_class, [])

                for item in items:
                    certainty = item.get("_additional", {}).get("certainty", 0)

                    # Skip low-confidence results
                    if certainty < self.confidence_threshold:
                        continue

                    doc = RetrievedDocument(
                        content=item.get("content", ""),
                        title=item.get("title", ""),
                        category=item.get("category", ""),
                        relevance_score=certainty,
                        metadata={
                            "themes": item.get("themes", []),
                            "lesson": item.get("lessonLearned", ""),
                            "access_level": item.get("accessLevel", ""),
                        },
                        weaviate_id=item.get("_additional", {}).get("id", ""),
                    )
                    documents.append(doc)

            return documents

        except Exception as e:
            print(f"Warning: Weaviate retrieval failed: {e}")
            return []

    def _build_context(self, documents: List[RetrievedDocument]) -> str:
        """Build context string from retrieved documents"""
        if not documents:
            return "No relevant memories found."

        context_parts = []
        for i, doc in enumerate(documents, 1):
            context_parts.append(f"[Memory {i}]")
            context_parts.append(doc.to_context_string())
            context_parts.append("")

        return "\n".join(context_parts)

    def _generate_answer(
        self,
        question: str,
        context: str,
        chat_history: str = ""
    ) -> Tuple[str, int]:
        """
        Generate answer using LLM.

        Returns:
            Tuple of (answer, tokens_used)
        """
        if not self.llm:
            return self._generate_fallback_answer(question, context), 0

        if not LANGCHAIN_AVAILABLE or not hasattr(self, 'qa_chain'):
            return self._generate_fallback_answer(question, context), 0

        try:
            result = self.qa_chain.run(
                context=context,
                chat_history=chat_history,
                question=question
            )
            # Token counting would require model-specific implementation
            return result.strip(), 0

        except Exception as e:
            print(f"Warning: LLM generation failed: {e}")
            return self._generate_fallback_answer(question, context), 0

    def _generate_fallback_answer(self, question: str, context: str) -> str:
        """Generate a fallback answer when LLM is unavailable"""
        if "No relevant memories found" in context:
            return (
                "I don't have specific information about that in my memories. "
                "Could you rephrase your question, or ask about something else?"
            )

        return (
            f"Based on the available memories, here's what I found:\n\n"
            f"{context}\n\n"
            f"Note: This is a direct excerpt from stored memories. "
            f"For a more conversational response, ensure the LLM is configured."
        )

    def ask(
        self,
        question: str,
        filters: Optional[Dict] = None,
        include_history: bool = True
    ) -> QAResult:
        """
        Ask a question and get an answer with sources.

        Args:
            question: The question to answer
            filters: Optional Weaviate filters (e.g., by category)
            include_history: Whether to include conversation history

        Returns:
            QAResult with answer and sources
        """
        import time

        if not question or not question.strip():
            return QAResult(
                question="",
                answer="Please ask a question.",
                confidence=0.0
            )

        # Step 1: Retrieve relevant documents
        retrieval_start = time.time()
        documents = self._retrieve_documents(question, filters)
        retrieval_time = (time.time() - retrieval_start) * 1000

        # Step 2: Build context
        context = self._build_context(documents)

        # Step 3: Get conversation history
        chat_history = ""
        if include_history and self.memory:
            try:
                memory_vars = self.memory.load_memory_variables({})
                chat_history = memory_vars.get("chat_history", "")
            except Exception:
                chat_history = ""

        # Step 4: Generate answer
        generation_start = time.time()
        answer, tokens = self._generate_answer(question, context, chat_history)
        generation_time = (time.time() - generation_start) * 1000

        # Step 5: Calculate confidence
        if documents:
            avg_relevance = sum(d.relevance_score for d in documents) / len(documents)
            confidence = min(1.0, avg_relevance)
        else:
            confidence = 0.3  # Low confidence without sources

        # Step 6: Update conversation memory
        if self.memory:
            try:
                self.memory.save_context(
                    {"input": question},
                    {"output": answer}
                )
            except Exception:
                pass

        result = QAResult(
            question=question,
            answer=answer,
            sources=documents,
            confidence=confidence,
            tokens_used=tokens,
            retrieval_time_ms=retrieval_time,
            generation_time_ms=generation_time,
        )

        # Log to MongoDB if available
        if self.mongodb_client:
            self._log_query(result)

        return result

    def _log_query(self, result: QAResult) -> None:
        """Log query to MongoDB"""
        try:
            if self.mongodb_client:
                log_entry = result.to_dict()
                log_entry["source_ids"] = [s.weaviate_id for s in result.sources]
                self.mongodb_client.qa_logs.insert_one(log_entry)
        except Exception as e:
            print(f"Warning: Failed to log QA query: {e}")

    def clear_memory(self) -> None:
        """Clear conversation memory"""
        if self.memory:
            self.memory.clear()

    def add_to_memory(self, question: str, answer: str) -> None:
        """Manually add Q&A to memory"""
        if self.memory:
            self.memory.save_context(
                {"input": question},
                {"output": answer}
            )


# =============================================================================
# SPECIALIZED QA CHAINS
# =============================================================================

class MemoryQAChain(QARetrievalChain):
    """QA chain specialized for ShaneBrain Legacy memories"""

    def __init__(self, **kwargs):
        kwargs.setdefault("weaviate_class", "ShanebrainMemory")
        super().__init__(**kwargs)

    def ask_about_value(self, value: str) -> QAResult:
        """Ask about a specific value"""
        return self.ask(
            f"What are Shane's thoughts on {value}?",
            filters={
                "path": ["category"],
                "operator": "Equal",
                "valueText": "value"
            }
        )

    def ask_for_story(self, topic: str) -> QAResult:
        """Ask for a story about a topic"""
        return self.ask(
            f"Tell me a story about {topic}",
            filters={
                "path": ["category"],
                "operator": "Equal",
                "valueText": "story"
            }
        )


class SecurityQAChain(QARetrievalChain):
    """QA chain specialized for Pulsar security events"""

    def __init__(self, **kwargs):
        kwargs.setdefault("weaviate_class", "PulsarSecurityEvent")
        super().__init__(**kwargs)

    def ask_about_threat(self, threat_type: str) -> QAResult:
        """Ask about a specific threat type"""
        return self.ask(
            f"What should I know about {threat_type} attacks?",
            filters={
                "path": ["attackVector"],
                "operator": "ContainsAny",
                "valueTextArray": [threat_type]
            }
        )


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

def create_qa_chain(
    weaviate_host: str = "localhost",
    weaviate_port: int = 8080,
    llm=None,
) -> Optional[QARetrievalChain]:
    """
    Factory function to create a QA chain with default configuration.

    Args:
        weaviate_host: Weaviate host
        weaviate_port: Weaviate port
        llm: Optional LLM instance

    Returns:
        Configured QARetrievalChain or None if setup fails
    """
    weaviate_client = None

    if WEAVIATE_AVAILABLE:
        try:
            weaviate_client = weaviate.connect_to_local(
                host=weaviate_host,
                port=weaviate_port
            )
            if not weaviate_client.is_ready():
                print("Warning: Weaviate is not ready")
                weaviate_client.close()
                weaviate_client = None
        except Exception as e:
            print(f"Warning: Could not connect to Weaviate: {e}")

    return QARetrievalChain(
        llm=llm,
        weaviate_client=weaviate_client,
    )


# =============================================================================
# EXAMPLE USAGE
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("ShaneBrain QA Retrieval Chain - Demo")
    print("=" * 60)

    # Create chain without dependencies (demo mode)
    chain = QARetrievalChain(
        llm=None,
        weaviate_client=None,
    )

    # Demo questions
    questions = [
        "What are Shane's core values?",
        "Tell me about Shane's family",
        "What is ADHD and how does Shane view it?",
    ]

    print("\nDemo Questions (without Weaviate connection):\n")

    for question in questions:
        result = chain.ask(question)
        print(f"Q: {question}")
        print(f"A: {result.answer[:200]}..." if len(result.answer) > 200 else f"A: {result.answer}")
        print(f"Confidence: {result.confidence:.2f}")
        print(f"Sources: {len(result.sources)}")
        print()

    print("=" * 60)
    print("To use with real data, connect to Weaviate and add an LLM.")
    print("=" * 60)
