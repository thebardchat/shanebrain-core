"""
ShaneBrain Core - Code Generation Chain
========================================

LangChain-based code generation for ShaneBrain projects.

This chain:
- Generates code based on natural language requirements
- Follows project-specific patterns and conventions
- Includes security considerations
- Works with local Llama model

Usage:
    from langchain_chains.code_generation_chain import CodeGenerationChain

    chain = CodeGenerationChain(llm=llm)
    result = chain.generate(
        "Create a function to validate email addresses",
        language="python",
        project="angel_cloud"
    )
    print(result.code)

Author: Shane Brazelton
"""

import os
import re
from datetime import datetime
from dataclasses import dataclass, field
from typing import List, Optional, Dict, Any, Tuple
from enum import Enum

# LangChain imports
try:
    from langchain.prompts import PromptTemplate
    from langchain.chains import LLMChain
    LANGCHAIN_AVAILABLE = True
except ImportError:
    LANGCHAIN_AVAILABLE = False


# =============================================================================
# CONFIGURATION
# =============================================================================

class Language(Enum):
    """Supported programming languages"""
    PYTHON = "python"
    JAVASCRIPT = "javascript"
    TYPESCRIPT = "typescript"
    SOLIDITY = "solidity"
    SQL = "sql"
    BASH = "bash"


class Project(Enum):
    """ShaneBrain projects"""
    ANGEL_CLOUD = "angel_cloud"
    SHANEBRAIN_LEGACY = "shanebrain_legacy"
    PULSAR = "pulsar"
    LOGIBOT = "logibot"
    GENERAL = "general"


# Project-specific guidelines
PROJECT_GUIDELINES = {
    Project.ANGEL_CLOUD: """
- Always validate user input
- Include error handling for mental health data
- Never log sensitive content directly
- Include crisis detection hooks where appropriate
- Follow HIPAA-aware principles
- Prioritize user safety over functionality
""",
    Project.SHANEBRAIN_LEGACY: """
- Handle personal data with encryption
- Include family access level checks
- Preserve authentic voice and personality
- Add comprehensive documentation
- Consider long-term preservation
""",
    Project.PULSAR: """
- Security-first approach
- Validate all blockchain data
- Handle large numbers carefully (BigInt)
- Include rate limiting for APIs
- Log security events appropriately
- Never expose private keys or sensitive addresses
""",
    Project.LOGIBOT: """
- Handle dispatch workflow interruptions gracefully
- Include audit logging for business operations
- Validate financial calculations precisely
- Support offline operation where possible
- Keep UI simple and ADHD-friendly
""",
    Project.GENERAL: """
- Follow clean code principles
- Include comprehensive error handling
- Add clear documentation
- Write testable code
- Consider edge cases
""",
}

# Language-specific templates
CODE_GENERATION_TEMPLATES = {
    Language.PYTHON: '''"""
{docstring}
"""

{imports}

{code}
''',
    Language.JAVASCRIPT: '''/**
 * {docstring}
 */

{imports}

{code}
''',
    Language.TYPESCRIPT: '''/**
 * {docstring}
 */

{imports}

{code}
''',
    Language.SOLIDITY: '''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title {title}
 * @dev {docstring}
 */

{code}
''',
}


# =============================================================================
# PROMPT TEMPLATES
# =============================================================================

GENERATION_PROMPT = """You are an expert programmer helping with the ShaneBrain project.

Generate clean, secure, well-documented code based on the following requirements:

**Requirements:**
{requirements}

**Language:** {language}

**Project:** {project}

**Project Guidelines:**
{guidelines}

**Additional Context:**
{context}

**Important:**
- Write production-ready code
- Include comprehensive error handling
- Add clear comments and documentation
- Follow language best practices
- Consider security implications
- Make code testable

Generate the code:

```{language}
"""

REVIEW_PROMPT = """Review this code for security issues, bugs, and improvements:

```{language}
{code}
```

Provide:
1. Security issues (if any)
2. Bugs or potential issues
3. Suggested improvements
4. Overall assessment

Review:"""


# =============================================================================
# DATA CLASSES
# =============================================================================

@dataclass
class CodeGenerationResult:
    """Result of code generation"""
    code: str
    language: Language
    project: Project
    requirements: str
    imports: List[str] = field(default_factory=list)
    documentation: str = ""
    security_notes: List[str] = field(default_factory=list)
    test_suggestions: List[str] = field(default_factory=list)
    tokens_used: int = 0
    generation_time_ms: float = 0.0
    timestamp: datetime = field(default_factory=datetime.now)

    def to_file_content(self) -> str:
        """Format as complete file content"""
        template = CODE_GENERATION_TEMPLATES.get(
            self.language,
            "{code}"
        )
        return template.format(
            docstring=self.documentation,
            imports="\n".join(self.imports),
            code=self.code,
            title=self.requirements.split()[0] if self.requirements else "Generated"
        )

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for storage"""
        return {
            "code_length": len(self.code),
            "language": self.language.value,
            "project": self.project.value,
            "requirements": self.requirements,
            "security_notes_count": len(self.security_notes),
            "tokens_used": self.tokens_used,
            "generation_time_ms": self.generation_time_ms,
            "timestamp": self.timestamp.isoformat(),
        }


@dataclass
class CodeReviewResult:
    """Result of code review"""
    security_issues: List[str] = field(default_factory=list)
    bugs: List[str] = field(default_factory=list)
    improvements: List[str] = field(default_factory=list)
    overall_assessment: str = ""
    risk_level: str = "low"  # low, medium, high


# =============================================================================
# CODE GENERATION CHAIN
# =============================================================================

class CodeGenerationChain:
    """
    LangChain-based code generation with project-specific guidelines.

    Uses local Llama model for generation, with built-in security
    checks and project-specific conventions.
    """

    def __init__(
        self,
        llm=None,
        weaviate_client=None,
        mongodb_client=None,
        default_language: Language = Language.PYTHON,
        default_project: Project = Project.GENERAL,
    ):
        """
        Initialize the code generation chain.

        Args:
            llm: LangChain LLM instance
            weaviate_client: Weaviate client for retrieving examples
            mongodb_client: MongoDB client for logging
            default_language: Default programming language
            default_project: Default project context
        """
        self.llm = llm
        self.weaviate_client = weaviate_client
        self.mongodb_client = mongodb_client
        self.default_language = default_language
        self.default_project = default_project

        self._init_chains()

    def _init_chains(self) -> None:
        """Initialize LangChain chains"""
        if not LANGCHAIN_AVAILABLE:
            return

        # Generation prompt
        self.generation_prompt = PromptTemplate(
            input_variables=[
                "requirements", "language", "project",
                "guidelines", "context"
            ],
            template=GENERATION_PROMPT
        )

        # Review prompt
        self.review_prompt = PromptTemplate(
            input_variables=["language", "code"],
            template=REVIEW_PROMPT
        )

        if self.llm:
            self.generation_chain = LLMChain(
                llm=self.llm,
                prompt=self.generation_prompt,
                verbose=False
            )
            self.review_chain = LLMChain(
                llm=self.llm,
                prompt=self.review_prompt,
                verbose=False
            )

    def _get_context(self, requirements: str, language: Language) -> str:
        """Retrieve relevant code examples from Weaviate"""
        if not self.weaviate_client:
            return "No additional context available."

        # Would query Weaviate for similar code examples
        # For now, return empty
        return ""

    def _extract_code(self, raw_output: str, language: Language) -> str:
        """Extract code from LLM output"""
        # Try to find code block
        pattern = rf"```{language.value}?\s*\n?(.*?)```"
        match = re.search(pattern, raw_output, re.DOTALL | re.IGNORECASE)

        if match:
            return match.group(1).strip()

        # If no code block, return cleaned output
        return raw_output.strip()

    def _extract_imports(self, code: str, language: Language) -> List[str]:
        """Extract import statements from code"""
        imports = []

        if language == Language.PYTHON:
            import_pattern = r'^(import .+|from .+ import .+)$'
            for line in code.split('\n'):
                if re.match(import_pattern, line.strip()):
                    imports.append(line.strip())

        elif language in [Language.JAVASCRIPT, Language.TYPESCRIPT]:
            import_pattern = r'^(import .+|const .+ = require\(.+\))$'
            for line in code.split('\n'):
                if re.match(import_pattern, line.strip()):
                    imports.append(line.strip())

        return imports

    def _check_security(self, code: str, language: Language) -> List[str]:
        """Check code for basic security issues"""
        security_notes = []

        # Common patterns to flag
        dangerous_patterns = {
            "eval(": "Using eval() is dangerous - consider alternatives",
            "exec(": "Using exec() is dangerous - consider alternatives",
            "shell=True": "shell=True is a security risk - validate inputs carefully",
            "pickle.loads": "Unpickling untrusted data is dangerous",
            "password": "Ensure passwords are not hardcoded",
            "api_key": "Ensure API keys are not hardcoded",
            "secret": "Ensure secrets are loaded from environment variables",
            "innerHTML": "Using innerHTML can lead to XSS - use textContent instead",
            "dangerouslySetInnerHTML": "Avoid dangerouslySetInnerHTML when possible",
        }

        code_lower = code.lower()
        for pattern, note in dangerous_patterns.items():
            if pattern.lower() in code_lower:
                security_notes.append(note)

        # Language-specific checks
        if language == Language.SOLIDITY:
            if "tx.origin" in code:
                security_notes.append("tx.origin can be manipulated - use msg.sender")
            if "selfdestruct" in code:
                security_notes.append("selfdestruct is dangerous and deprecated")
            if ".call{" in code and "reentrancy" not in code.lower():
                security_notes.append("Low-level call detected - ensure reentrancy protection")

        return security_notes

    def _generate_test_suggestions(
        self,
        code: str,
        language: Language
    ) -> List[str]:
        """Generate suggestions for tests"""
        suggestions = []

        if language == Language.PYTHON:
            # Find function definitions
            func_pattern = r'def (\w+)\('
            functions = re.findall(func_pattern, code)
            for func in functions:
                if not func.startswith('_'):
                    suggestions.append(f"Test {func}() with valid inputs")
                    suggestions.append(f"Test {func}() with edge cases")
                    suggestions.append(f"Test {func}() with invalid inputs")

        elif language == Language.SOLIDITY:
            # Find function definitions
            func_pattern = r'function (\w+)\('
            functions = re.findall(func_pattern, code)
            for func in functions:
                suggestions.append(f"Test {func}() happy path")
                suggestions.append(f"Test {func}() access control")
                suggestions.append(f"Test {func}() with edge values")

        return suggestions[:10]  # Limit suggestions

    def generate(
        self,
        requirements: str,
        language: Optional[Language] = None,
        project: Optional[Project] = None,
        context: str = "",
    ) -> CodeGenerationResult:
        """
        Generate code based on requirements.

        Args:
            requirements: Natural language description of what to build
            language: Target programming language
            project: Project context for guidelines
            context: Additional context

        Returns:
            CodeGenerationResult with generated code
        """
        import time

        language = language or self.default_language
        project = project or self.default_project
        guidelines = PROJECT_GUIDELINES.get(project, PROJECT_GUIDELINES[Project.GENERAL])

        # Get additional context from Weaviate
        retrieved_context = self._get_context(requirements, language)
        full_context = f"{context}\n{retrieved_context}".strip()

        generation_start = time.time()

        # Generate code
        if self.llm and LANGCHAIN_AVAILABLE and hasattr(self, 'generation_chain'):
            try:
                raw_output = self.generation_chain.run(
                    requirements=requirements,
                    language=language.value,
                    project=project.value,
                    guidelines=guidelines,
                    context=full_context or "None"
                )
                code = self._extract_code(raw_output, language)
            except Exception as e:
                print(f"Warning: Code generation failed: {e}")
                code = self._generate_fallback_code(requirements, language)
        else:
            code = self._generate_fallback_code(requirements, language)

        generation_time = (time.time() - generation_start) * 1000

        # Extract imports
        imports = self._extract_imports(code, language)

        # Security check
        security_notes = self._check_security(code, language)

        # Test suggestions
        test_suggestions = self._generate_test_suggestions(code, language)

        result = CodeGenerationResult(
            code=code,
            language=language,
            project=project,
            requirements=requirements,
            imports=imports,
            documentation=requirements,
            security_notes=security_notes,
            test_suggestions=test_suggestions,
            generation_time_ms=generation_time,
        )

        # Log to MongoDB
        if self.mongodb_client:
            self._log_generation(result)

        return result

    def _generate_fallback_code(
        self,
        requirements: str,
        language: Language
    ) -> str:
        """Generate placeholder code when LLM is unavailable"""
        templates = {
            Language.PYTHON: f'''# TODO: Implement - {requirements}
# LLM not available for code generation

def placeholder():
    """
    {requirements}

    This is a placeholder. Connect an LLM to generate actual code.
    """
    raise NotImplementedError("Code generation requires LLM connection")
''',
            Language.JAVASCRIPT: f'''// TODO: Implement - {requirements}
// LLM not available for code generation

function placeholder() {{
    /**
     * {requirements}
     *
     * This is a placeholder. Connect an LLM to generate actual code.
     */
    throw new Error("Code generation requires LLM connection");
}}
''',
        }

        return templates.get(language, f"// TODO: {requirements}")

    def review(self, code: str, language: Language) -> CodeReviewResult:
        """
        Review code for issues and improvements.

        Args:
            code: Code to review
            language: Programming language

        Returns:
            CodeReviewResult with findings
        """
        # Always run basic security checks
        security_issues = self._check_security(code, language)

        # LLM-based review if available
        if self.llm and LANGCHAIN_AVAILABLE and hasattr(self, 'review_chain'):
            try:
                raw_review = self.review_chain.run(
                    language=language.value,
                    code=code
                )
                # Parse review (simplified)
                return CodeReviewResult(
                    security_issues=security_issues,
                    bugs=[],
                    improvements=[],
                    overall_assessment=raw_review,
                    risk_level="medium" if security_issues else "low"
                )
            except Exception as e:
                print(f"Warning: Code review failed: {e}")

        return CodeReviewResult(
            security_issues=security_issues,
            bugs=[],
            improvements=["LLM review unavailable - manual review recommended"],
            overall_assessment="Basic security scan completed. Full review requires LLM.",
            risk_level="medium" if security_issues else "low"
        )

    def _log_generation(self, result: CodeGenerationResult) -> None:
        """Log generation to MongoDB"""
        try:
            if self.mongodb_client:
                self.mongodb_client.code_generations.insert_one(result.to_dict())
        except Exception as e:
            print(f"Warning: Failed to log code generation: {e}")


# =============================================================================
# SPECIALIZED GENERATORS
# =============================================================================

class CrisisDetectionCodeGenerator(CodeGenerationChain):
    """Specialized generator for Angel Cloud crisis detection code"""

    def __init__(self, **kwargs):
        kwargs.setdefault("default_project", Project.ANGEL_CLOUD)
        kwargs.setdefault("default_language", Language.PYTHON)
        super().__init__(**kwargs)

    def generate_detector(self, detection_type: str) -> CodeGenerationResult:
        """Generate crisis detection code"""
        requirements = f"""
        Create a {detection_type} detector for mental health crisis detection.

        Requirements:
        - Analyze text for signs of {detection_type}
        - Return a score from 0.0 to 1.0
        - Include explanation of detection
        - Handle edge cases safely
        - Never false negative on safety-critical content
        """
        return self.generate(requirements)


class SmartContractGenerator(CodeGenerationChain):
    """Specialized generator for Pulsar Solidity contracts"""

    def __init__(self, **kwargs):
        kwargs.setdefault("default_project", Project.PULSAR)
        kwargs.setdefault("default_language", Language.SOLIDITY)
        super().__init__(**kwargs)

    def generate_security_check(self, check_type: str) -> CodeGenerationResult:
        """Generate security check function"""
        requirements = f"""
        Create a Solidity function to check for {check_type} vulnerabilities.

        Requirements:
        - Gas efficient
        - Include NatSpec documentation
        - Handle all edge cases
        - Follow OpenZeppelin patterns where applicable
        - Include events for monitoring
        """
        return self.generate(requirements)


# =============================================================================
# EXAMPLE USAGE
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("ShaneBrain Code Generation Chain - Demo")
    print("=" * 60)

    # Create chain without LLM (demo mode)
    chain = CodeGenerationChain()

    # Demo generation
    result = chain.generate(
        requirements="Create a function to validate and sanitize user email input",
        language=Language.PYTHON,
        project=Project.ANGEL_CLOUD
    )

    print("\nGenerated Code:")
    print("-" * 40)
    print(result.code)
    print("-" * 40)

    print(f"\nLanguage: {result.language.value}")
    print(f"Project: {result.project.value}")
    print(f"Security Notes: {result.security_notes}")
    print(f"Test Suggestions: {result.test_suggestions[:3]}")

    print("\n" + "=" * 60)
    print("To generate actual code, connect an LLM to the chain.")
    print("=" * 60)
