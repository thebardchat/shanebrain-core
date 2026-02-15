"""
ShaneBrain Social Bot
Facebook automation with Weaviate knowledge harvesting.
"""

import sys
import os

# Ensure shanebrain-core root is on sys.path for scripts.weaviate_helpers
_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _root not in sys.path:
    sys.path.insert(0, _root)
