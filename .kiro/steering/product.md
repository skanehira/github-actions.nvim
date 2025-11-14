# Product Overview

A Neovim plugin that enhances GitHub Actions workflow development by providing inline version checking, workflow dispatch capabilities, and run history viewing directly within the editor.

## Core Capabilities

- **Inline Version Checking**: Automatically displays GitHub Actions version status (latest/outdated/error) as virtual text in workflow files, using treesitter to parse `uses:` declarations
- **Workflow Dispatch**: Trigger workflows with `workflow_dispatch` support, including interactive input prompts and branch selection
- **Run History Viewer**: Browse workflow run history with expandable jobs/steps, live log viewing, and watch mode for in-progress runs

## Target Use Cases

- **Workflow Maintenance**: Keep GitHub Actions versions up-to-date by identifying outdated actions at a glance
- **Development Iteration**: Quickly dispatch workflows with custom inputs and branches without leaving the editor
- **Debugging & Monitoring**: Investigate workflow failures by viewing logs and run details within Neovim

## Value Proposition

Integrates GitHub Actions management into the Neovim workflow, eliminating context switches to the browser for common tasks like version checking, workflow triggering, and log viewing. Leverages existing tools (gh CLI, treesitter) rather than reinventing infrastructure.

---
_Created: 2025-11-12_
