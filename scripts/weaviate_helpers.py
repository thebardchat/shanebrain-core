#!/usr/bin/env python3
"""
Weaviate Helper Functions for ShaneBrain Core
Provides reusable functions for interacting with Weaviate collections.
Compatible with weaviate-client v4.
"""

import weaviate
from weaviate.classes.query import Filter, MetadataQuery
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
import uuid


class WeaviateHelper:
    """Helper class for Weaviate operations in ShaneBrain."""

    def __init__(self, url: str = "localhost:8080"):
        """Initialize connection to Weaviate."""
        self._client = None
        self._url = url

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def connect(self):
        """Establish connection to Weaviate."""
        if self._client is None:
            self._client = weaviate.connect_to_local()
        return self._client

    def close(self):
        """Close the Weaviate connection."""
        if self._client:
            self._client.close()
            self._client = None

    @property
    def client(self):
        """Get the Weaviate client, connecting if necessary."""
        if self._client is None:
            self.connect()
        return self._client

    def is_ready(self) -> bool:
        """Check if Weaviate is ready."""
        try:
            return self.client.is_ready()
        except:
            return False

    # =========================================================================
    # Conversation Operations
    # =========================================================================

    def log_conversation(
        self,
        message: str,
        role: str,
        mode: str = "CHAT",
        session_id: Optional[str] = None,
        timestamp: Optional[datetime] = None
    ) -> Optional[str]:
        """
        Log a conversation message to Weaviate.

        Args:
            message: The message content
            role: Role (user, assistant, system)
            mode: Agent mode (CHAT, MEMORY, WELLNESS, SECURITY, DISPATCH, CODE)
            session_id: Session identifier (generated if not provided)
            timestamp: Message timestamp (now if not provided)

        Returns:
            The UUID of the created object, or None on error
        """
        if not self.client.collections.exists("Conversation"):
            return None

        collection = self.client.collections.get("Conversation")

        data = {
            "message": message,
            "role": role,
            "mode": mode,
            "session_id": session_id or str(uuid.uuid4()),
            "timestamp": (timestamp or datetime.now(timezone.utc)).isoformat()
        }

        try:
            result = collection.data.insert(data)
            return str(result)
        except Exception as e:
            print(f"Error logging conversation: {e}")
            return None

    def get_conversation_history(
        self,
        session_id: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        Get conversation history for a session.

        Args:
            session_id: The session identifier
            limit: Maximum messages to return

        Returns:
            List of conversation messages
        """
        if not self.client.collections.exists("Conversation"):
            return []

        collection = self.client.collections.get("Conversation")

        try:
            response = collection.query.fetch_objects(
                filters=Filter.by_property("session_id").equal(session_id),
                limit=limit
            )
            return [obj.properties for obj in response.objects]
        except:
            return []

    def search_conversations(
        self,
        query: str,
        mode: Optional[str] = None,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Search conversations semantically.

        Args:
            query: Search query
            mode: Optional mode filter
            limit: Maximum results

        Returns:
            List of matching messages
        """
        if not self.client.collections.exists("Conversation"):
            return []

        collection = self.client.collections.get("Conversation")

        try:
            if mode:
                response = collection.query.near_text(
                    query=query,
                    filters=Filter.by_property("mode").equal(mode),
                    limit=limit
                )
            else:
                response = collection.query.near_text(
                    query=query,
                    limit=limit
                )
            return [obj.properties for obj in response.objects]
        except:
            return []

    # =========================================================================
    # Legacy Knowledge Operations
    # =========================================================================

    def add_knowledge(
        self,
        content: str,
        category: str,
        source: str = "manual",
        title: Optional[str] = None
    ) -> Optional[str]:
        """
        Add knowledge to LegacyKnowledge collection.

        Args:
            content: The knowledge content
            category: Category (family, faith, technical, philosophy, general, wellness)
            source: Source of the knowledge
            title: Optional title

        Returns:
            UUID of created object or None
        """
        if not self.client.collections.exists("LegacyKnowledge"):
            return None

        collection = self.client.collections.get("LegacyKnowledge")

        data = {
            "content": content,
            "category": category,
            "source": source,
        }
        if title:
            data["title"] = title

        try:
            result = collection.data.insert(data)
            return str(result)
        except Exception as e:
            print(f"Error adding knowledge: {e}")
            return None

    def search_knowledge(
        self,
        query: str,
        category: Optional[str] = None,
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Search legacy knowledge semantically.

        Args:
            query: Search query
            category: Optional category filter
            limit: Maximum results

        Returns:
            List of matching knowledge entries
        """
        if not self.client.collections.exists("LegacyKnowledge"):
            return []

        collection = self.client.collections.get("LegacyKnowledge")

        try:
            if category:
                response = collection.query.near_text(
                    query=query,
                    filters=Filter.by_property("category").equal(category),
                    limit=limit,
                    return_metadata=MetadataQuery(distance=True)
                )
            else:
                response = collection.query.near_text(
                    query=query,
                    limit=limit,
                    return_metadata=MetadataQuery(distance=True)
                )

            results = []
            for obj in response.objects:
                entry = obj.properties.copy()
                if obj.metadata and obj.metadata.distance is not None:
                    entry["_distance"] = obj.metadata.distance
                results.append(entry)
            return results
        except:
            return []

    # =========================================================================
    # Crisis Log Operations
    # =========================================================================

    def log_crisis(
        self,
        input_text: str,
        severity: str,
        session_id: Optional[str] = None,
        response_given: Optional[str] = None,
        timestamp: Optional[datetime] = None
    ) -> Optional[str]:
        """
        Log a crisis detection event.

        Args:
            input_text: The triggering user input
            severity: Severity level (low, medium, high, critical)
            session_id: Session identifier
            response_given: The response provided to the user
            timestamp: Event timestamp

        Returns:
            UUID of created log or None
        """
        if not self.client.collections.exists("CrisisLog"):
            return None

        collection = self.client.collections.get("CrisisLog")

        data = {
            "input_text": input_text,
            "severity": severity,
            "timestamp": (timestamp or datetime.now(timezone.utc)).isoformat()
        }
        if session_id:
            data["session_id"] = session_id
        if response_given:
            data["response_given"] = response_given

        try:
            result = collection.data.insert(data)
            return str(result)
        except Exception as e:
            print(f"Error logging crisis: {e}")
            return None

    def get_recent_crises(
        self,
        severity: Optional[str] = None,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        """
        Get recent crisis logs.

        Args:
            severity: Optional severity filter
            limit: Maximum results

        Returns:
            List of crisis log entries
        """
        if not self.client.collections.exists("CrisisLog"):
            return []

        collection = self.client.collections.get("CrisisLog")

        try:
            if severity:
                response = collection.query.fetch_objects(
                    filters=Filter.by_property("severity").equal(severity),
                    limit=limit
                )
            else:
                response = collection.query.fetch_objects(limit=limit)
            return [obj.properties for obj in response.objects]
        except:
            return []

    # =========================================================================
    # Social Knowledge Operations
    # =========================================================================

    def log_social_interaction(
        self,
        content: str,
        author_name: str,
        author_id: str,
        interaction_type: str,
        source_post_id: str,
        sentiment: str = "neutral",
        context: str = "",
        relationship_tags: Optional[List[str]] = None,
        knowledge_extracted: str = "",
        timestamp: Optional[datetime] = None
    ) -> Optional[str]:
        """
        Log a social media interaction to Weaviate.

        Args:
            content: The interaction content (comment text, reaction, etc.)
            author_name: Name of the person
            author_id: Facebook user ID
            interaction_type: Type (comment, reaction, share, post)
            source_post_id: Facebook post ID this came from
            sentiment: Sentiment (positive, negative, neutral, supportive)
            context: Additional context
            relationship_tags: Tags like friend, family, supporter
            knowledge_extracted: Key knowledge from this interaction
            timestamp: When the interaction occurred

        Returns:
            UUID of created object or None
        """
        if not self.client.collections.exists("SocialKnowledge"):
            return None

        collection = self.client.collections.get("SocialKnowledge")

        data = {
            "content": content,
            "author_name": author_name,
            "author_id": author_id,
            "interaction_type": interaction_type,
            "sentiment": sentiment,
            "context": context,
            "source_post_id": source_post_id,
            "timestamp": (timestamp or datetime.now(timezone.utc)).isoformat(),
            "relationship_tags": relationship_tags or [],
            "knowledge_extracted": knowledge_extracted,
        }

        try:
            result = collection.data.insert(data)
            return str(result)
        except Exception as e:
            print(f"Error logging social interaction: {e}")
            return None

    def search_social_knowledge(
        self,
        query: str,
        interaction_type: Optional[str] = None,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Search social knowledge semantically.

        Args:
            query: Search query
            interaction_type: Optional filter (comment, reaction, share, post)
            limit: Maximum results

        Returns:
            List of matching social interactions
        """
        if not self.client.collections.exists("SocialKnowledge"):
            return []

        collection = self.client.collections.get("SocialKnowledge")

        try:
            if interaction_type:
                response = collection.query.near_text(
                    query=query,
                    filters=Filter.by_property("interaction_type").equal(interaction_type),
                    limit=limit,
                    return_metadata=MetadataQuery(distance=True)
                )
            else:
                response = collection.query.near_text(
                    query=query,
                    limit=limit,
                    return_metadata=MetadataQuery(distance=True)
                )

            results = []
            for obj in response.objects:
                entry = obj.properties.copy()
                if obj.metadata and obj.metadata.distance is not None:
                    entry["_distance"] = obj.metadata.distance
                results.append(entry)
            return results
        except:
            return []

    def get_interactions_by_author(
        self,
        author_id: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """
        Get all interactions from a specific author.

        Args:
            author_id: Facebook user ID
            limit: Maximum results

        Returns:
            List of interactions from this author
        """
        if not self.client.collections.exists("SocialKnowledge"):
            return []

        collection = self.client.collections.get("SocialKnowledge")

        try:
            response = collection.query.fetch_objects(
                filters=Filter.by_property("author_id").equal(author_id),
                limit=limit
            )
            return [obj.properties for obj in response.objects]
        except:
            return []

    def get_interactions_by_post(
        self,
        post_id: str,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """
        Get all interactions for a specific post.

        Args:
            post_id: Facebook post ID
            limit: Maximum results

        Returns:
            List of interactions on this post
        """
        if not self.client.collections.exists("SocialKnowledge"):
            return []

        collection = self.client.collections.get("SocialKnowledge")

        try:
            response = collection.query.fetch_objects(
                filters=Filter.by_property("source_post_id").equal(post_id),
                limit=limit
            )
            return [obj.properties for obj in response.objects]
        except:
            return []

    # =========================================================================
    # Friend Profile Operations
    # =========================================================================

    def upsert_friend_profile(
        self,
        name: str,
        facebook_id: str,
        sentiment: str = "neutral",
        topics: Optional[List[str]] = None,
        summary: Optional[str] = None
    ) -> Optional[str]:
        """
        Create or update a friend profile. If the profile exists (by facebook_id),
        increments interaction_count, updates last_seen, merges topics, and
        recalculates relationship_strength.

        Args:
            name: Person's display name
            facebook_id: Facebook user ID
            sentiment: Sentiment of this interaction
            topics: Topics from this interaction
            summary: Updated AI summary (if regenerating)

        Returns:
            UUID of created/updated object or None
        """
        if not self.client.collections.exists("FriendProfile"):
            return None

        collection = self.client.collections.get("FriendProfile")
        now = datetime.now(timezone.utc)

        try:
            # Check if profile exists
            existing = collection.query.fetch_objects(
                filters=Filter.by_property("facebook_id").equal(facebook_id),
                limit=1
            )

            if existing.objects:
                obj = existing.objects[0]
                props = obj.properties
                count = (props.get("interaction_count") or 0) + 1

                # Merge topics
                existing_topics = props.get("topics_discussed") or []
                new_topics = list(set(existing_topics + (topics or [])))

                # Recalculate relationship strength (log scale, caps at 1.0)
                import math
                strength = min(1.0, math.log(count + 1) / math.log(100))

                update_data = {
                    "name": name,
                    "interaction_count": count,
                    "last_seen": now.isoformat(),
                    "sentiment_profile": sentiment,
                    "topics_discussed": new_topics,
                    "relationship_strength": strength,
                }
                if summary:
                    update_data["summary"] = summary

                collection.data.update(
                    uuid=obj.uuid,
                    properties=update_data
                )
                return str(obj.uuid)
            else:
                # Create new profile
                data = {
                    "name": name,
                    "facebook_id": facebook_id,
                    "interaction_count": 1,
                    "first_seen": now.isoformat(),
                    "last_seen": now.isoformat(),
                    "sentiment_profile": sentiment,
                    "topics_discussed": topics or [],
                    "relationship_strength": 0.1,
                    "summary": summary or f"New commenter: {name}",
                }
                result = collection.data.insert(data)
                return str(result)

        except Exception as e:
            print(f"Error upserting friend profile: {e}")
            return None

    def get_friend_profile(
        self,
        facebook_id: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get a friend profile by Facebook ID.

        Args:
            facebook_id: Facebook user ID

        Returns:
            Profile dict or None
        """
        if not self.client.collections.exists("FriendProfile"):
            return None

        collection = self.client.collections.get("FriendProfile")

        try:
            response = collection.query.fetch_objects(
                filters=Filter.by_property("facebook_id").equal(facebook_id),
                limit=1
            )
            if response.objects:
                return response.objects[0].properties
            return None
        except:
            return None

    def search_friends(
        self,
        query: str,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Search friend profiles semantically.

        Args:
            query: Search query
            limit: Maximum results

        Returns:
            List of matching friend profiles
        """
        if not self.client.collections.exists("FriendProfile"):
            return []

        collection = self.client.collections.get("FriendProfile")

        try:
            response = collection.query.near_text(
                query=query,
                limit=limit,
                return_metadata=MetadataQuery(distance=True)
            )

            results = []
            for obj in response.objects:
                entry = obj.properties.copy()
                if obj.metadata and obj.metadata.distance is not None:
                    entry["_distance"] = obj.metadata.distance
                results.append(entry)
            return results
        except:
            return []

    def get_top_friends(
        self,
        limit: int = 10
    ) -> List[Dict[str, Any]]:
        """
        Get friend profiles sorted by relationship strength (highest first).

        Args:
            limit: Maximum results

        Returns:
            List of friend profiles
        """
        if not self.client.collections.exists("FriendProfile"):
            return []

        collection = self.client.collections.get("FriendProfile")

        try:
            response = collection.query.fetch_objects(limit=limit * 3)
            profiles = [obj.properties for obj in response.objects]
            profiles.sort(key=lambda p: p.get("relationship_strength", 0), reverse=True)
            return profiles[:limit]
        except:
            return []

    # =========================================================================
    # Utility Operations
    # =========================================================================

    def get_collection_count(self, collection_name: str) -> int:
        """Get the number of objects in a collection."""
        if not self.client.collections.exists(collection_name):
            return 0

        try:
            collection = self.client.collections.get(collection_name)
            response = collection.aggregate.over_all(total_count=True)
            return response.total_count
        except:
            return 0

    def collection_exists(self, name: str) -> bool:
        """Check if a collection exists."""
        return self.client.collections.exists(name)


# =========================================================================
# CLI Demo
# =========================================================================

if __name__ == "__main__":
    import sys

    print("\n" + "="*60)
    print("     ShaneBrain Weaviate Helper Demo")
    print("="*60 + "\n")

    with WeaviateHelper() as helper:
        if not helper.is_ready():
            print("Weaviate is not ready. Make sure it's running.")
            sys.exit(1)

        print("✓ Connected to Weaviate\n")

        # Show collection counts
        print("Collection counts:")
        for name in ['Conversation', 'LegacyKnowledge', 'CrisisLog', 'SocialKnowledge', 'FriendProfile']:
            count = helper.get_collection_count(name)
            exists = helper.collection_exists(name)
            status = f"{count} records" if exists else "not created"
            print(f"  • {name}: {status}")

        # Demo: Search knowledge
        print("\nDemo: Searching LegacyKnowledge for 'family'...")
        results = helper.search_knowledge("family", limit=2)
        if results:
            for r in results:
                title = r.get('title', 'Untitled')[:40]
                dist = r.get('_distance', 'N/A')
                print(f"  • {title} (distance: {dist})")
        else:
            print("  (no results or collection not set up)")

    print("\n" + "="*60 + "\n")
