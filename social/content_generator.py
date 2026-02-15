"""
Content generator for ShaneBrain Social Bot.
Uses Ollama for post text generation and sentiment analysis.
Uses Pollinations.ai for free AI-generated images.
"""

import random
import requests
from urllib.parse import quote
from . import config
from .content_calendar import get_todays_theme


class ContentGenerator:
    """Generate Facebook post content using local Ollama LLM."""

    def __init__(self):
        self.ollama_url = config.OLLAMA_HOST
        self.model = config.OLLAMA_MODEL
        self.personality = config.PAGE_PERSONALITY

    def _ollama_generate(self, prompt, temperature=0.8):
        """Call Ollama's generate endpoint."""
        resp = requests.post(
            f"{self.ollama_url}/api/generate",
            json={
                "model": self.model,
                "prompt": prompt,
                "stream": False,
                "options": {"temperature": temperature},
            },
            timeout=300,
        )
        if not resp.ok:
            raise RuntimeError(f"Ollama error: {resp.status_code} {resp.reason}. Is Ollama running?")

        data = resp.json()
        text = data.get("response", "").strip()
        if not text:
            raise RuntimeError("Ollama returned empty response")
        return text

    def generate_post(self, topic=None, mood=None, max_length=280, use_calendar=True):
        """
        Generate a Facebook post.

        Args:
            topic: Specific topic (overrides calendar)
            mood: Mood/tone (overrides calendar)
            max_length: Character limit
            use_calendar: Use today's themed calendar if no topic given

        Returns:
            Generated post text
        """
        # Use calendar theme if no specific topic
        if use_calendar and not topic:
            theme = get_todays_theme()
            topic = random.choice(theme["topics"])
            mood = mood or theme["mood"]

        prompt = f"""You are {self.personality}. Write a single Facebook post.

Rules:
- Keep it under {max_length} characters
- Be authentic and conversational
- No hashtags unless they feel natural
- No emoji overload (1-2 max if any)
- Don't start with "Hey everyone" or similar generic openers
- Make it feel like a real person wrote it"""

        if topic:
            prompt += f"\n- Topic: {topic}"
        if mood:
            prompt += f"\n- Mood/tone: {mood}"

        prompt += "\n\nWrite only the post text, nothing else."

        return self._ollama_generate(prompt)

    def generate_image_url(self, post_text):
        """
        Generate a Pollinations.ai image URL based on post content.
        Facebook will fetch the image from this URL when posting.

        Args:
            post_text: The post text to base the image on

        Returns:
            Pollinations.ai image URL
        """
        # Generate a concise image prompt from the post
        image_prompt = self._ollama_generate(
            f"Based on this Facebook post, write a short (10 words max) image description "
            f"for an AI image generator. Describe a warm, positive scene. "
            f"Just the description, nothing else.\n\nPost: {post_text}",
            temperature=0.6,
        )

        # Clean and encode for URL
        image_prompt = image_prompt.strip('"\'').strip()[:100]
        encoded = quote(image_prompt)
        return f"https://image.pollinations.ai/prompt/{encoded}?width=1200&height=630&nologo=true"

    def analyze_sentiment(self, text):
        """
        Analyze sentiment of a comment or interaction.

        Args:
            text: Text to analyze

        Returns:
            Sentiment string: positive, negative, neutral, or supportive
        """
        # Quick keyword check first (saves Ollama call for obvious cases)
        text_lower = text.lower()
        positive_words = ["love", "great", "amazing", "awesome", "thank", "blessed", "proud", "congrats"]
        negative_words = ["hate", "stupid", "terrible", "worst", "angry", "disappointed"]
        supportive_words = ["praying", "support", "here for you", "got your back", "amen", "keep going"]

        for word in supportive_words:
            if word in text_lower:
                return "supportive"
        for word in negative_words:
            if word in text_lower:
                return "negative"
        for word in positive_words:
            if word in text_lower:
                return "positive"

        # Fall back to Ollama for ambiguous text
        try:
            result = self._ollama_generate(
                f"Classify the sentiment of this Facebook comment as exactly one word: "
                f"positive, negative, neutral, or supportive.\n\n"
                f"Comment: {text}\n\nSentiment:",
                temperature=0.1,
            )
            sentiment = result.strip().lower().rstrip(".")
            if sentiment in ("positive", "negative", "neutral", "supportive"):
                return sentiment
            return "neutral"
        except Exception:
            return "neutral"

    def generate_reply(self, comment_text, commenter_name):
        """
        Generate a reply to a Facebook comment.

        Args:
            comment_text: The comment to reply to
            commenter_name: Name of the commenter

        Returns:
            Reply text
        """
        prompt = f"""You are {self.personality}. Someone named {commenter_name} commented on your Facebook post.

Their comment: "{comment_text}"

Write a brief, warm, authentic reply (under 150 characters). Be yourself — real, not corporate.
Just the reply text, nothing else."""

        return self._ollama_generate(prompt, temperature=0.7)

    def generate_ideas(self, count=5):
        """Generate post ideas."""
        prompt = f"""You are {self.personality}. Generate {count} distinct Facebook post ideas.

Each idea should be:
- A brief 1-line description
- Varied in topic and tone
- Authentic to the personality

Format: One idea per line, numbered 1-{count}. Just the ideas, no extra text."""

        return self._ollama_generate(prompt)

    def extract_topics(self, text):
        """Extract discussion topics from a comment for friend profiling."""
        try:
            result = self._ollama_generate(
                f"From this Facebook comment, list 1-3 topic tags (single words or short phrases). "
                f"Return only comma-separated tags, nothing else.\n\n"
                f"Comment: {text}\n\nTopics:",
                temperature=0.2,
            )
            topics = [t.strip().lower() for t in result.split(",") if t.strip()]
            return topics[:3]
        except Exception:
            return []
