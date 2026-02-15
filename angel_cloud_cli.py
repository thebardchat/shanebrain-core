#!/usr/bin/env python3
"""Angel Cloud CLI — lightweight terminal interface for ShaneBrain."""

import argparse
import sys

import requests

OLLAMA_URL = "http://localhost:11434"
MODEL = "llama3.2:1b"


def check_ollama() -> bool:
    """Check if Ollama is reachable."""
    try:
        resp = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
        return resp.status_code == 200
    except requests.ConnectionError:
        return False


def load_system_prompt(path: str = "RAG.md") -> str:
    """Load the system prompt from RAG.md."""
    try:
        with open(path) as f:
            return f.read()
    except FileNotFoundError:
        return "You are ShaneBrain, a helpful personal AI assistant."


def chat(user_message: str, history: list[dict], system_prompt: str, model: str = None) -> str:
    """Send a message to Ollama and return the response."""
    messages = [{"role": "system", "content": system_prompt}]
    messages.extend(history)
    messages.append({"role": "user", "content": user_message})

    resp = requests.post(
        f"{OLLAMA_URL}/api/chat",
        json={"model": model or MODEL, "messages": messages, "stream": False},
        timeout=120,
    )
    resp.raise_for_status()
    return resp.json()["message"]["content"]


def interactive_mode(system_prompt: str, model: str = MODEL) -> None:
    """Run an interactive chat session."""
    history: list[dict] = []
    print(f"ShaneBrain CLI ({model}) — type 'quit' to exit\n")

    while True:
        try:
            user_input = input("You: ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nGoodbye.")
            break

        if not user_input:
            continue
        if user_input.lower() in ("quit", "exit", "q"):
            print("Goodbye.")
            break

        try:
            response = chat(user_input, history, system_prompt, model)
            print(f"\nShaneBrain: {response}\n")
            history.append({"role": "user", "content": user_input})
            history.append({"role": "assistant", "content": response})
        except requests.RequestException as e:
            print(f"\nError talking to Ollama: {e}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Angel Cloud CLI — ShaneBrain interface")
    parser.add_argument("prompt", nargs="?", help="One-shot prompt (omit for interactive mode)")
    parser.add_argument("--model", default=MODEL, help=f"Ollama model (default: {MODEL})")
    parser.add_argument("--rag", default="RAG.md", help="Path to RAG/personality file")
    parser.add_argument("--status", action="store_true", help="Check Ollama status and exit")
    args = parser.parse_args()

    if args.status:
        if check_ollama():
            print("Ollama is running.")
            resp = requests.get(f"{OLLAMA_URL}/api/tags", timeout=5)
            models = [m["name"] for m in resp.json().get("models", [])]
            print(f"Available models: {', '.join(models)}")
        else:
            print("Ollama is not reachable.")
        sys.exit(0)

    if not check_ollama():
        print("Error: Cannot reach Ollama. Is it running?")
        print(f"  Expected at: {OLLAMA_URL}")
        sys.exit(1)

    model = args.model
    system_prompt = load_system_prompt(args.rag)

    if args.prompt:
        response = chat(args.prompt, [], system_prompt, model)
        print(response)
    else:
        interactive_mode(system_prompt, model)


if __name__ == "__main__":
    main()
