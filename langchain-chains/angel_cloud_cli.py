#!/usr/bin/env python3
"""
Angel Cloud - Mental Wellness CLI Interface
============================================

A compassionate AI companion for mental wellness support.
Part of the ShaneBrain Core ecosystem.

Features:
- Crisis detection and resource provision
- Supportive conversation with local LLM
- Offline-capable (runs entirely on your hardware)
- Privacy-first (no data leaves your machine)

Usage:
    python angel_cloud_cli.py

Author: Shane Brazelton
"""

import os
import sys
from pathlib import Path
from datetime import datetime

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

try:
    from rich.console import Console
    from rich.panel import Panel
    from rich.text import Text
    from rich.markdown import Markdown
    from rich.theme import Theme
    from rich.prompt import Prompt
    from rich.live import Live
    from rich.spinner import Spinner
    RICH_AVAILABLE = True
except ImportError:
    RICH_AVAILABLE = False
    print("Warning: 'rich' not installed. Install with: pip install rich")

try:
    from prompt_toolkit import prompt as pt_prompt
    from prompt_toolkit.history import FileHistory
    from prompt_toolkit.auto_suggest import AutoSuggestFromHistory
    PROMPT_TOOLKIT_AVAILABLE = True
except ImportError:
    PROMPT_TOOLKIT_AVAILABLE = False

from shanebrain_agent import ShaneBrainAgent, AgentMode, AgentResponse
from crisis_detection_chain import CrisisLevel

# =============================================================================
# CONFIGURATION
# =============================================================================

ANGEL_CLOUD_THEME = Theme({
    "info": "cyan",
    "warning": "yellow",
    "error": "red",
    "success": "green",
    "user": "bold blue",
    "angel": "bold magenta",
    "crisis.low": "yellow",
    "crisis.medium": "orange3",
    "crisis.high": "red",
    "crisis.critical": "bold red on white",
})

WELCOME_MESSAGE = """
[bold cyan]Angel Cloud[/bold cyan] - Mental Wellness Companion

Welcome. I'm here to listen, support, and help you navigate
whatever you're going through. This is a safe, private space.

[dim]Your conversations stay on your device. No data is sent anywhere.[/dim]

Commands:
  [cyan]/help[/cyan]    - Show available commands
  [cyan]/clear[/cyan]   - Clear conversation history
  [cyan]/mode[/cyan]    - Switch agent mode
  [cyan]/status[/cyan]  - Show system status
  [cyan]/exit[/cyan]    - Exit Angel Cloud

[dim]Just type to chat. I'm listening.[/dim]
"""

CRISIS_RESOURCES = """
[bold red]Crisis Resources[/bold red]

If you're in immediate danger, please reach out:

  [bold]988[/bold] - Suicide & Crisis Lifeline (call or text)
  [bold]741741[/bold] - Crisis Text Line (text HOME)
  [bold]1-800-662-4357[/bold] - SAMHSA National Helpline

You matter. Help is available 24/7.
"""

# =============================================================================
# ANGEL CLOUD CLI
# =============================================================================

class AngelCloudCLI:
    """Interactive CLI for Angel Cloud mental wellness support."""

    def __init__(self):
        self.console = Console(theme=ANGEL_CLOUD_THEME) if RICH_AVAILABLE else None
        self.agent = None
        self.running = False
        self.history_file = Path.home() / ".angel_cloud_history"

    def print(self, message: str, style: str = None):
        """Print with optional styling."""
        if self.console:
            self.console.print(message, style=style)
        else:
            print(message)

    def print_panel(self, content: str, title: str = None, border_style: str = "cyan"):
        """Print content in a panel."""
        if self.console:
            self.console.print(Panel(content, title=title, border_style=border_style))
        else:
            print(f"--- {title or 'Panel'} ---")
            print(content)
            print("-" * 40)

    def initialize(self) -> bool:
        """Initialize the Angel Cloud agent."""
        self.print("\n[dim]Initializing Angel Cloud...[/dim]")

        try:
            # Create agent in wellness mode
            self.agent = ShaneBrainAgent.from_config()
            self.agent.set_mode(AgentMode.WELLNESS)

            # Status check
            status_parts = []
            if self.agent.llm:
                status_parts.append("[green]LLM: Connected[/green]")
            else:
                status_parts.append("[yellow]LLM: Offline mode[/yellow]")

            if self.agent.weaviate_client:
                status_parts.append("[green]Memory: Connected[/green]")
            else:
                status_parts.append("[dim]Memory: Not available[/dim]")

            if self.agent.crisis_chain:
                status_parts.append("[green]Crisis Detection: Active[/green]")
            else:
                status_parts.append("[yellow]Crisis Detection: Limited[/yellow]")

            self.print("  " + " | ".join(status_parts))
            return True

        except Exception as e:
            self.print(f"[red]Error initializing: {e}[/red]")
            return False

    def get_input(self) -> str:
        """Get user input with history support."""
        try:
            if PROMPT_TOOLKIT_AVAILABLE:
                return pt_prompt(
                    "You: ",
                    history=FileHistory(str(self.history_file)),
                    auto_suggest=AutoSuggestFromHistory(),
                ).strip()
            else:
                return input("You: ").strip()
        except (EOFError, KeyboardInterrupt):
            return "/exit"

    def format_response(self, response: AgentResponse) -> str:
        """Format agent response for display."""
        text = response.message

        # Add crisis indicator if detected
        if response.crisis_detected:
            level = response.crisis_level or "detected"
            if level in ["high", "critical"]:
                return f"[crisis.{level}]{text}[/crisis.{level}]"

        return text

    def handle_command(self, command: str) -> bool:
        """Handle slash commands. Returns False to exit."""
        cmd = command.lower().strip()

        if cmd in ["/exit", "/quit", "/q"]:
            self.print("\n[dim]Take care of yourself. You matter.[/dim]")
            return False

        elif cmd == "/help":
            help_text = """
[bold]Available Commands:[/bold]

  [cyan]/help[/cyan]     - Show this help message
  [cyan]/clear[/cyan]    - Clear conversation memory
  [cyan]/mode[/cyan]     - Show/switch agent mode
  [cyan]/status[/cyan]   - Show system status
  [cyan]/crisis[/cyan]   - Show crisis resources
  [cyan]/exit[/cyan]     - Exit Angel Cloud

[bold]Tips:[/bold]
  - Just type naturally to chat
  - I'm here to listen, not judge
  - Take breaks when you need them
"""
            self.print_panel(help_text, title="Help", border_style="cyan")

        elif cmd == "/clear":
            if self.agent:
                self.agent.clear_memory()
            self.print("[dim]Conversation history cleared.[/dim]")

        elif cmd == "/status":
            if self.agent:
                status = f"""
[bold]System Status[/bold]

Mode: {self.agent.context.mode.value}
Session: {self.agent.context.session_id[:8]}...
LLM: {'Connected' if self.agent.llm else 'Not available'}
Memory: {'Connected' if self.agent.weaviate_client else 'Not available'}
Crisis Detection: {'Active' if self.agent.crisis_chain else 'Limited'}
"""
                self.print_panel(status, title="Status", border_style="blue")
            else:
                self.print("[yellow]Agent not initialized[/yellow]")

        elif cmd == "/crisis":
            self.print_panel(CRISIS_RESOURCES, title="Crisis Resources", border_style="red")

        elif cmd.startswith("/mode"):
            parts = cmd.split()
            if len(parts) == 1:
                # Show current mode
                if self.agent:
                    self.print(f"Current mode: [bold]{self.agent.context.mode.value}[/bold]")
                    self.print("[dim]Available: chat, memory, wellness, security, dispatch, code[/dim]")
            else:
                # Switch mode
                mode_name = parts[1].upper()
                try:
                    new_mode = AgentMode[mode_name]
                    if self.agent:
                        self.agent.set_mode(new_mode)
                        self.print(f"[green]Switched to {new_mode.value} mode[/green]")
                except KeyError:
                    self.print(f"[red]Unknown mode: {parts[1]}[/red]")
        else:
            self.print(f"[yellow]Unknown command: {command}[/yellow]")
            self.print("[dim]Type /help for available commands[/dim]")

        return True

    def chat(self, message: str) -> None:
        """Process a chat message and display response."""
        if not self.agent:
            self.print("[red]Agent not initialized[/red]")
            return

        try:
            # Show thinking indicator
            if self.console:
                with self.console.status("[dim]Thinking...[/dim]", spinner="dots"):
                    response = self.agent.chat(message)
            else:
                print("Thinking...")
                response = self.agent.chat(message)

            # Format and display response
            formatted = self.format_response(response)

            if self.console:
                self.console.print()
                self.console.print("[angel]Angel Cloud:[/angel]", end=" ")
                self.console.print(Markdown(response.message))
            else:
                print(f"\nAngel Cloud: {response.message}")

            # Show crisis resources if high severity detected
            if response.crisis_detected and response.crisis_level in ["high", "critical"]:
                self.print()
                self.print_panel(CRISIS_RESOURCES, title="Resources", border_style="red")

        except Exception as e:
            self.print(f"[red]Error: {e}[/red]")

    def run(self) -> None:
        """Run the interactive CLI."""
        # Clear screen
        if self.console:
            self.console.clear()

        # Show welcome
        if self.console:
            self.console.print(Panel(
                Markdown(WELCOME_MESSAGE.replace("[bold cyan]", "**").replace("[/bold cyan]", "**")
                         .replace("[cyan]", "`").replace("[/cyan]", "`")
                         .replace("[dim]", "_").replace("[/dim]", "_")),
                title="[bold cyan]Angel Cloud[/bold cyan]",
                border_style="cyan",
                padding=(1, 2),
            ))
        else:
            print("=" * 60)
            print("Angel Cloud - Mental Wellness Companion")
            print("=" * 60)
            print(WELCOME_MESSAGE)

        # Initialize
        if not self.initialize():
            self.print("\n[yellow]Running in limited mode. Some features may not work.[/yellow]")
            # Create basic agent without connections
            self.agent = ShaneBrainAgent(enable_crisis_detection=True)
            self.agent.set_mode(AgentMode.WELLNESS)

        self.print()
        self.running = True

        # Main loop
        while self.running:
            try:
                user_input = self.get_input()

                if not user_input:
                    continue

                if user_input.startswith("/"):
                    self.running = self.handle_command(user_input)
                else:
                    self.chat(user_input)

                self.print()  # Blank line between exchanges

            except KeyboardInterrupt:
                self.print("\n[dim]Use /exit to quit properly.[/dim]")
            except Exception as e:
                self.print(f"[red]Unexpected error: {e}[/red]")

        self.print("\n[bold cyan]Thank you for using Angel Cloud. Take care.[/bold cyan]\n")


# =============================================================================
# MAIN
# =============================================================================

def main():
    """Main entry point."""
    cli = AngelCloudCLI()
    cli.run()


if __name__ == "__main__":
    main()
