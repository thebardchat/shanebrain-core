"""
ShaneBrain Core - Crisis Detection Chain
=========================================

LangChain-based crisis detection for Angel Cloud mental wellness platform.

This chain:
- Detects crisis keywords and patterns
- Scores messages for crisis severity (0.0 to 1.0)
- Generates appropriate responses based on severity
- Integrates with Weaviate for context and MongoDB for logging

Usage:
    from langchain_chains.crisis_detection_chain import CrisisDetectionChain

    chain = CrisisDetectionChain()
    result = chain.detect("I can't go on anymore")
    print(result.crisis_level)  # "high"
    print(result.response)  # Appropriate supportive response

Author: Shane Brazelton
Security: Handles sensitive mental health data - no logging of content
"""

import os
import re
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any
from enum import Enum

# LangChain imports
try:
    from langchain_core.prompts import PromptTemplate
    from langchain_classic.chains import LLMChain
    from langchain_core.output_parsers import BaseOutputParser
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False
    print("Warning: LangChain not installed. Install with: pip install langchain langchain-core")


# =============================================================================
# CONFIGURATION
# =============================================================================

class CrisisLevel(Enum):
    """Crisis severity levels"""
    NONE = "none"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


# Crisis keywords - organized by severity
CRISIS_KEYWORDS = {
    CrisisLevel.CRITICAL: [
        "suicide", "kill myself", "end my life", "end it all",
        "don't want to live", "better off dead", "want to die",
        "goodbye forever", "final message", "this is the end",
        "i'm going to do it", "tonight's the night",
    ],
    CrisisLevel.HIGH: [
        "self-harm", "hurt myself", "cutting", "overdose",
        "can't go on", "no reason to live", "hopeless",
        "worthless", "no one cares", "burden to everyone",
        "ending it", "checking out",
    ],
    CrisisLevel.MEDIUM: [
        "depressed", "anxious", "panic attack", "can't cope",
        "overwhelmed", "breaking down", "falling apart",
        "losing control", "can't take it", "drowning",
        "trapped", "no way out",
    ],
    CrisisLevel.LOW: [
        "stressed", "sad", "worried", "struggling",
        "hard time", "difficult", "tired of",
        "frustrated", "upset", "lonely",
    ],
}

# Response templates by crisis level
RESPONSE_TEMPLATES = {
    CrisisLevel.CRITICAL: """I hear that you're in a lot of pain right now. Your life matters, and I want you to know that help is available right now.

Please reach out to one of these resources immediately:
- National Suicide Prevention Lifeline: 988 (call or text)
- Crisis Text Line: Text HOME to 741741
- International Association for Suicide Prevention: https://www.iasp.info/resources/Crisis_Centres/

You don't have to face this alone. These trained counselors are available 24/7 and want to help.

Would you like to talk about what's happening? I'm here to listen.""",

    CrisisLevel.HIGH: """I'm concerned about what you're sharing, and I want you to know that you matter. What you're feeling is real and valid, but there are people who can help.

Here are some resources that might help:
- National Suicide Prevention Lifeline: 988
- Crisis Text Line: Text HOME to 741741
- SAMHSA National Helpline: 1-800-662-4357

Would it help to talk about what's going on? I'm here and I care.""",

    CrisisLevel.MEDIUM: """It sounds like you're going through a really difficult time. I want you to know that it's okay to feel this way, and you don't have to face it alone.

Some resources that might help:
- SAMHSA National Helpline: 1-800-662-4357 (free, confidential, 24/7)
- NAMI Helpline: 1-800-950-6264
- Your local community mental health center

Would you like to talk more about what you're experiencing?""",

    CrisisLevel.LOW: """I hear that things have been challenging. It takes courage to share how you're feeling.

Would you like to talk about what's on your mind? Sometimes it helps to process things out loud.

If you ever feel like you need more support, remember that help is always available.""",

    CrisisLevel.NONE: """I'm here and listening. How can I support you today?""",
}


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class CrisisDetectionResult:
    """Result of crisis detection analysis"""
    crisis_level: CrisisLevel
    crisis_score: float  # 0.0 to 1.0
    keywords_found: List[str] = field(default_factory=list)
    patterns_matched: List[str] = field(default_factory=list)
    confidence: float = 0.0
    response: str = ""
    resources_provided: List[Dict[str, str]] = field(default_factory=list)
    should_escalate: bool = False
    escalation_reason: Optional[str] = None
    analysis_timestamp: datetime = field(default_factory=datetime.now)

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for storage"""
        return {
            "crisis_level": self.crisis_level.value,
            "crisis_score": self.crisis_score,
            "keywords_found": self.keywords_found,
            "patterns_matched": self.patterns_matched,
            "confidence": self.confidence,
            "should_escalate": self.should_escalate,
            "escalation_reason": self.escalation_reason,
            "analysis_timestamp": self.analysis_timestamp.isoformat(),
        }


# =============================================================================
# CRISIS DETECTION CHAIN
# =============================================================================

class CrisisDetectionChain:
    """
    LangChain-based crisis detection for mental health messages.

    This chain combines:
    - Keyword matching for known crisis indicators
    - Pattern detection for contextual analysis
    - LLM-based analysis for nuanced understanding
    - Severity scoring and appropriate response generation
    """

    def __init__(
        self,
        llm=None,
        weaviate_client=None,
        mongodb_client=None,
        enable_llm_analysis: bool = True,
        crisis_threshold: float = 0.7,
    ):
        """
        Initialize the crisis detection chain.

        Args:
            llm: LangChain LLM instance (optional, for advanced analysis)
            weaviate_client: Weaviate client for context retrieval
            mongodb_client: MongoDB client for logging
            enable_llm_analysis: Whether to use LLM for additional analysis
            crisis_threshold: Threshold for "high" crisis classification
        """
        self.llm = llm
        self.weaviate_client = weaviate_client
        self.mongodb_client = mongodb_client
        self.enable_llm_analysis = enable_llm_analysis and llm is not None
        self.crisis_threshold = crisis_threshold

        # Compile keyword patterns for efficient matching
        self._compile_patterns()

        # Initialize LLM chain if available
        if self.enable_llm_analysis and LANGCHAIN_AVAILABLE:
            self._init_llm_chain()

    def _compile_patterns(self) -> None:
        """Compile regex patterns for keyword matching"""
        self.compiled_patterns = {}
        for level, keywords in CRISIS_KEYWORDS.items():
            patterns = []
            for keyword in keywords:
                # Create pattern that matches the keyword with word boundaries
                pattern = re.compile(
                    r'\b' + re.escape(keyword.lower()) + r'\b',
                    re.IGNORECASE
                )
                patterns.append((keyword, pattern))
            self.compiled_patterns[level] = patterns

    def _init_llm_chain(self) -> None:
        """Initialize the LLM analysis chain"""
        if not LANGCHAIN_AVAILABLE:
            return

        prompt_template = """Analyze the following message for signs of mental health crisis or distress.

Message: {message}

Provide a brief analysis considering:
1. Emotional state indicators
2. Level of distress (none, mild, moderate, severe)
3. Any immediate safety concerns
4. Recommended response approach

Be compassionate and err on the side of caution for safety.

Analysis:"""

        self.analysis_prompt = PromptTemplate(
            input_variables=["message"],
            template=prompt_template
        )

        if self.llm:
            self.analysis_chain = LLMChain(
                llm=self.llm,
                prompt=self.analysis_prompt
            )

    def _keyword_analysis(self, message: str) -> tuple[CrisisLevel, List[str], float]:
        """
        Analyze message for crisis keywords.

        Returns:
            Tuple of (highest_level, keywords_found, score)
        """
        message_lower = message.lower()
        keywords_found = []
        highest_level = CrisisLevel.NONE

        # Check each level from highest to lowest
        for level in [CrisisLevel.CRITICAL, CrisisLevel.HIGH,
                      CrisisLevel.MEDIUM, CrisisLevel.LOW]:
            for keyword, pattern in self.compiled_patterns[level]:
                if pattern.search(message_lower):
                    keywords_found.append(keyword)
                    if level.value > highest_level.value or highest_level == CrisisLevel.NONE:
                        highest_level = level

        # Calculate score based on level and keyword count
        level_scores = {
            CrisisLevel.NONE: 0.0,
            CrisisLevel.LOW: 0.25,
            CrisisLevel.MEDIUM: 0.5,
            CrisisLevel.HIGH: 0.75,
            CrisisLevel.CRITICAL: 1.0,
        }

        base_score = level_scores[highest_level]
        # Add a small boost for multiple keywords (max 0.1)
        keyword_boost = min(0.1, len(keywords_found) * 0.02)
        score = min(1.0, base_score + keyword_boost)

        return highest_level, keywords_found, score

    def _pattern_analysis(self, message: str) -> List[str]:
        """
        Analyze message for concerning patterns beyond keywords.

        Returns:
            List of patterns detected
        """
        patterns_found = []
        message_lower = message.lower()

        # Pattern: Farewell indicators
        farewell_patterns = [
            r"goodbye\s+everyone",
            r"tell\s+.+\s+i\s+love",
            r"take\s+care\s+of\s+.+\s+for\s+me",
            r"my\s+(will|belongings|stuff)",
            r"when\s+i('m|am)\s+gone",
        ]
        for pattern in farewell_patterns:
            if re.search(pattern, message_lower):
                patterns_found.append("farewell_indicator")
                break

        # Pattern: Time pressure
        urgency_patterns = [
            r"tonight",
            r"right\s+now",
            r"can't\s+wait",
            r"this\s+is\s+it",
            r"one\s+last",
        ]
        for pattern in urgency_patterns:
            if re.search(pattern, message_lower):
                patterns_found.append("urgency_indicator")
                break

        # Pattern: Isolation
        isolation_patterns = [
            r"no\s+one\s+(understands|cares|listens)",
            r"all\s+alone",
            r"nobody\s+would\s+(notice|care|miss)",
            r"everyone\s+(hates|left)",
        ]
        for pattern in isolation_patterns:
            if re.search(pattern, message_lower):
                patterns_found.append("isolation_indicator")
                break

        # Pattern: Planning indicators
        planning_patterns = [
            r"i('ve|have)\s+(decided|made\s+up\s+my\s+mind)",
            r"i('m|am)\s+going\s+to",
            r"(bought|got|found)\s+(pills|gun|rope)",
            r"my\s+plan\s+is",
        ]
        for pattern in planning_patterns:
            if re.search(pattern, message_lower):
                patterns_found.append("planning_indicator")
                break

        return patterns_found

    def _calculate_final_score(
        self,
        keyword_level: CrisisLevel,
        keyword_score: float,
        patterns: List[str],
        llm_analysis: Optional[str] = None
    ) -> tuple[CrisisLevel, float]:
        """
        Calculate final crisis level and score.

        Returns:
            Tuple of (final_level, final_score)
        """
        score = keyword_score

        # Pattern adjustments
        pattern_weights = {
            "farewell_indicator": 0.15,
            "urgency_indicator": 0.1,
            "isolation_indicator": 0.05,
            "planning_indicator": 0.2,
        }

        for pattern in patterns:
            if pattern in pattern_weights:
                score = min(1.0, score + pattern_weights[pattern])

        # Determine level from score
        if score >= 0.9:
            level = CrisisLevel.CRITICAL
        elif score >= self.crisis_threshold:
            level = CrisisLevel.HIGH
        elif score >= 0.5:
            level = CrisisLevel.MEDIUM
        elif score >= 0.25:
            level = CrisisLevel.LOW
        else:
            level = CrisisLevel.NONE

        return level, score

    def _get_response(self, level: CrisisLevel) -> str:
        """Get appropriate response for crisis level"""
        return RESPONSE_TEMPLATES.get(level, RESPONSE_TEMPLATES[CrisisLevel.NONE])

    def _get_resources(self, level: CrisisLevel) -> List[Dict[str, str]]:
        """Get relevant resources for crisis level"""
        resources = []

        if level in [CrisisLevel.CRITICAL, CrisisLevel.HIGH]:
            resources.extend([
                {
                    "type": "hotline",
                    "name": "National Suicide Prevention Lifeline",
                    "identifier": "988"
                },
                {
                    "type": "text",
                    "name": "Crisis Text Line",
                    "identifier": "Text HOME to 741741"
                },
            ])

        if level in [CrisisLevel.CRITICAL, CrisisLevel.HIGH, CrisisLevel.MEDIUM]:
            resources.extend([
                {
                    "type": "hotline",
                    "name": "SAMHSA National Helpline",
                    "identifier": "1-800-662-4357"
                },
            ])

        return resources

    def detect(self, message: str, context: Optional[Dict] = None) -> CrisisDetectionResult:
        """
        Detect crisis indicators in a message.

        Args:
            message: The message to analyze
            context: Optional context (conversation history, user info)

        Returns:
            CrisisDetectionResult with analysis
        """
        if not message or not message.strip():
            return CrisisDetectionResult(
                crisis_level=CrisisLevel.NONE,
                crisis_score=0.0,
                confidence=1.0,
                response=self._get_response(CrisisLevel.NONE)
            )

        # Step 1: Keyword analysis
        keyword_level, keywords_found, keyword_score = self._keyword_analysis(message)

        # Step 2: Pattern analysis
        patterns_found = self._pattern_analysis(message)

        # Step 3: LLM analysis (if enabled)
        llm_analysis = None
        if self.enable_llm_analysis and hasattr(self, 'analysis_chain'):
            try:
                llm_result = self.analysis_chain.run(message=message)
                llm_analysis = llm_result
            except Exception as e:
                # Don't let LLM failure block crisis detection
                print(f"Warning: LLM analysis failed: {e}")

        # Step 4: Calculate final score
        final_level, final_score = self._calculate_final_score(
            keyword_level, keyword_score, patterns_found, llm_analysis
        )

        # Step 5: Determine if escalation needed
        should_escalate = final_level in [CrisisLevel.CRITICAL, CrisisLevel.HIGH]
        escalation_reason = None
        if should_escalate:
            if "planning_indicator" in patterns_found:
                escalation_reason = "Active planning indicators detected"
            elif final_level == CrisisLevel.CRITICAL:
                escalation_reason = "Critical crisis keywords detected"
            else:
                escalation_reason = "High severity crisis indicators"

        # Step 6: Generate response and resources
        response = self._get_response(final_level)
        resources = self._get_resources(final_level)

        # Calculate confidence based on evidence
        evidence_count = len(keywords_found) + len(patterns_found)
        confidence = min(1.0, 0.5 + (evidence_count * 0.1))

        result = CrisisDetectionResult(
            crisis_level=final_level,
            crisis_score=final_score,
            keywords_found=keywords_found,
            patterns_matched=patterns_found,
            confidence=confidence,
            response=response,
            resources_provided=resources,
            should_escalate=should_escalate,
            escalation_reason=escalation_reason,
        )

        # Log to MongoDB if available (no content, just metadata)
        if self.mongodb_client and final_level != CrisisLevel.NONE:
            self._log_detection(result)

        return result

    def _log_detection(self, result: CrisisDetectionResult) -> None:
        """Log detection to MongoDB (metadata only, no content)"""
        try:
            if self.mongodb_client:
                log_entry = {
                    "crisis_level": result.crisis_level.value,
                    "crisis_score": result.crisis_score,
                    "keywords_count": len(result.keywords_found),
                    "patterns_count": len(result.patterns_matched),
                    "should_escalate": result.should_escalate,
                    "timestamp": result.analysis_timestamp,
                }
                # Don't log actual keywords or content for privacy
                self.mongodb_client.crisis_logs.insert_one(log_entry)
        except Exception as e:
            # Don't let logging failure affect detection
            print(f"Warning: Failed to log crisis detection: {e}")


# =============================================================================
# CONVENIENCE FUNCTIONS
# =============================================================================

def quick_crisis_check(message: str) -> CrisisDetectionResult:
    """
    Quick crisis check without full chain setup.

    Useful for simple keyword-based detection without LLM.

    Args:
        message: Message to check

    Returns:
        CrisisDetectionResult
    """
    chain = CrisisDetectionChain(enable_llm_analysis=False)
    return chain.detect(message)


def get_crisis_level_from_score(score: float) -> CrisisLevel:
    """Convert numerical score to crisis level"""
    if score >= 0.9:
        return CrisisLevel.CRITICAL
    elif score >= 0.7:
        return CrisisLevel.HIGH
    elif score >= 0.5:
        return CrisisLevel.MEDIUM
    elif score >= 0.25:
        return CrisisLevel.LOW
    else:
        return CrisisLevel.NONE


# =============================================================================
# EXAMPLE USAGE
# =============================================================================

if __name__ == "__main__":
    # Example usage demonstration
    print("=" * 60)
    print("ShaneBrain Crisis Detection Chain - Demo")
    print("=" * 60)

    # Create chain without LLM (keyword/pattern only)
    chain = CrisisDetectionChain(enable_llm_analysis=False)

    # Test messages
    test_messages = [
        "I'm having a great day!",
        "I've been feeling a bit stressed lately",
        "I'm so depressed, I don't know what to do",
        "I can't go on anymore, I feel hopeless",
        "I want to end it all tonight",
    ]

    print("\nAnalyzing test messages:\n")

    for message in test_messages:
        result = chain.detect(message)
        print(f"Message: \"{message[:50]}...\"" if len(message) > 50 else f"Message: \"{message}\"")
        print(f"  Level: {result.crisis_level.value}")
        print(f"  Score: {result.crisis_score:.2f}")
        print(f"  Keywords: {result.keywords_found}")
        print(f"  Patterns: {result.patterns_matched}")
        print(f"  Escalate: {result.should_escalate}")
        print()

    print("=" * 60)
    print("Demo complete. In production, connect to LLM for enhanced analysis.")
    print("=" * 60)
