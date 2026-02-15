#!/usr/bin/env python3
"""
ShaneBrain Learning Ingestion System
Watches inbox for new files and ingests them into Weaviate LegacyKnowledge.
Runs as a scheduled cron job (twice daily at 6am and 6pm).

Supported formats: .txt, .md, .pdf
"""

import re
import sys
import shutil
import logging
from pathlib import Path
from datetime import datetime

import weaviate

# Paths
LEARNING_ROOT = Path("/mnt/shanebrain-raid/shanebrain-learning")
INBOX = LEARNING_ROOT / "inbox"
PROCESSED = LEARNING_ROOT / "processed"
LOG_DIR = LEARNING_ROOT / "logs"

SUPPORTED_EXTENSIONS = {".txt", ".md", ".pdf"}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

# Setup logging
LOG_DIR.mkdir(parents=True, exist_ok=True)
log_file = LOG_DIR / f"ingest_{datetime.now().strftime('%Y%m%d')}.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_file),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger("learning_ingest")


def extract_text(filepath: Path) -> str | None:
    """Extract text content from a supported file."""
    suffix = filepath.suffix.lower()

    if suffix in (".txt", ".md"):
        try:
            return filepath.read_text(encoding="utf-8", errors="replace")
        except Exception as e:
            logger.error(f"Error reading {filepath.name}: {e}")
            return None

    if suffix == ".pdf":
        try:
            from pypdf import PdfReader
            reader = PdfReader(str(filepath))
            parts = [page.extract_text() for page in reader.pages if page.extract_text()]
            return "\n\n".join(parts) if parts else None
        except ImportError:
            logger.warning("pypdf not installed — skipping PDF: %s", filepath.name)
            return None
        except Exception as e:
            logger.error(f"Error reading PDF {filepath.name}: {e}")
            return None

    return None


def chunk_text(text: str, title: str, source: str, max_size: int = 2000) -> list[dict]:
    """Split text into chunks for Weaviate ingestion."""
    chunks = []

    if source.endswith(".md"):
        sections = re.split(r"\n(?=## )", text)
        for section in sections:
            section = section.strip()
            if len(section) < 10:
                continue
            if section.startswith("## "):
                header, _, body = section.partition("\n")
                header = header.replace("## ", "").strip()
                body = body.strip()
            else:
                header = title
                body = section
            if body:
                chunks.append({
                    "content": body[:max_size],
                    "category": "learned",
                    "source": source,
                    "title": header,
                })
    else:
        paragraphs = text.split("\n\n")
        current = ""
        num = 0
        for para in paragraphs:
            para = para.strip()
            if not para:
                continue
            if len(current) + len(para) + 2 > max_size:
                if current:
                    num += 1
                    chunks.append({
                        "content": current,
                        "category": "learned",
                        "source": source,
                        "title": f"{title} (part {num})",
                    })
                current = para
            else:
                current = f"{current}\n\n{para}" if current else para
        if current:
            num += 1
            chunks.append({
                "content": current,
                "category": "learned",
                "source": source,
                "title": title if num == 1 else f"{title} (part {num})",
            })

    return chunks


def ingest_to_weaviate(chunks: list[dict]) -> int:
    """Insert chunks into Weaviate LegacyKnowledge collection."""
    try:
        client = weaviate.connect_to_local()
    except Exception as e:
        logger.error(f"Cannot connect to Weaviate: {e}")
        return 0

    try:
        if not client.is_ready():
            logger.error("Weaviate is not ready")
            return 0

        if not client.collections.exists("LegacyKnowledge"):
            logger.error("LegacyKnowledge collection not found")
            return 0

        collection = client.collections.get("LegacyKnowledge")
        imported = 0

        for chunk in chunks:
            try:
                collection.data.insert(chunk)
                imported += 1
            except Exception as e:
                logger.error(f"Error inserting chunk '{chunk.get('title', '?')}': {e}")

        return imported
    finally:
        client.close()


def process_inbox() -> dict:
    """Process all files in the inbox."""
    INBOX.mkdir(parents=True, exist_ok=True)
    PROCESSED.mkdir(parents=True, exist_ok=True)

    files = sorted(
        f for f in INBOX.iterdir()
        if f.is_file() and f.suffix.lower() in SUPPORTED_EXTENSIONS
    )

    if not files:
        logger.info("No files in inbox to process")
        return {"processed": 0, "chunks": 0, "errors": 0}

    logger.info(f"Found {len(files)} file(s) to process")

    total_chunks = 0
    total_errors = 0
    processed_files = 0

    for filepath in files:
        logger.info(f"Processing: {filepath.name}")

        if filepath.stat().st_size > MAX_FILE_SIZE:
            logger.warning(f"Skipping {filepath.name}: exceeds 10MB limit")
            total_errors += 1
            continue

        text = extract_text(filepath)
        if not text or len(text.strip()) < 20:
            logger.warning(f"Skipping {filepath.name}: no usable text")
            total_errors += 1
            continue

        title = filepath.stem.replace("_", " ").replace("-", " ").title()
        chunks = chunk_text(text, title, filepath.name)
        logger.info(f"  Created {len(chunks)} chunk(s)")

        if not chunks:
            total_errors += 1
            continue

        imported = ingest_to_weaviate(chunks)
        logger.info(f"  Ingested {imported}/{len(chunks)} chunks")

        if imported > 0:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            dest = PROCESSED / f"{timestamp}_{filepath.name}"
            shutil.move(str(filepath), str(dest))
            logger.info(f"  Moved to: {dest.name}")
            processed_files += 1
            total_chunks += imported
        else:
            total_errors += 1
            logger.error(f"  Failed to ingest — leaving in inbox")

    return {"processed": processed_files, "chunks": total_chunks, "errors": total_errors}


def main():
    logger.info("=" * 50)
    logger.info("ShaneBrain Learning Ingest — Starting")
    logger.info("=" * 50)

    results = process_inbox()

    logger.info(f"Files processed: {results['processed']}")
    logger.info(f"Chunks ingested: {results['chunks']}")
    logger.info(f"Errors: {results['errors']}")
    logger.info("=" * 50)

    return 0 if results["errors"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
