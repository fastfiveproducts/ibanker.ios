# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Instructions
You MUST read ./AGENTS.md at the start of every conversation and re-read it, and any docs file its index pointed you to for the task in hand, after any context compaction. Follow all coding standards, project structure notes, and rules defined in [AGENTS.md](./AGENTS.md).

# Shell Commands
Never chain shell commands with `&&`, `;`, or `|`. Never use flags like `-C` to avoid `cd`. Run each command as its own separate Bash tool call. This is critical — chained commands break the permission system and slow down approved workflows.
