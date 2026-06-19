# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DevOS project using the **general** profile. Configuration stored in `.dev-os/config.yml`.
@AGENTS.md

<!-- DevOS:section:project-context -->
## Project Context

- **Project:** orca
- **DevOS profile:** `general`
<!-- /DevOS:section:project-context -->

<!-- DevOS:section:conventions -->
## Development Conventions

- Check project README and CLAUDE.md for stack-specific conventions
- **Standards:** 136 documents across `.dev-os/standards/global/` (extracted), `.dev-os/standards/profile/` (profile sync), and any project-local root standards
<!-- /DevOS:section:conventions -->

<!-- DevOS:section:safety-rules -->
## Safety Rules

- Before removing or overwriting config files, create a backup first
- Never bulk-delete files without explicit approval
- Do not commit secrets (`.env`, credentials, API keys) to git
- Before staging files for a commit, verify they are inside the git repository root
- Do not force-push to main/master
- Run tests before claiming a fix works
<!-- /DevOS:section:safety-rules -->

<!-- DevOS:section:directory-structure -->
## Key Directories

- `src/` — source code
- `tests/` — test files
- `docs/` — documentation
- `product/` — specs, planning, runtime (DevOS managed)
- `.dev-os/` — DevOS project configuration
<!-- /DevOS:section:directory-structure -->

<!-- DevOS:section:compatibility-posture -->
## Compatibility Posture

- Temporary pre-launch rule. Remove or revise when this project goes live.
- This project is not live yet and has no production customers.
- Breaking changes are acceptable if they simplify the product or close correctness gaps.
- Default to the best forward version, not backwards compatibility.
- Treat unfinished, unused, or dead code as unbuilt features.
- Prefer deletion or replacement over shims, adapters, compatibility layers, or legacy fallbacks.
- Do not add legacy shims, compatibility layers, migrations, or old-contract support unless explicitly requested.
<!-- /DevOS:section:compatibility-posture -->

<!-- DevOS:section:devos-context -->
## DevOS Context

Reference these context files in every session:

- `docs/context/DEVOS_CONTEXT_BUNDLE.md` — project summary, profile, version
- `docs/context/DEVOS_CAPABILITIES_INDEX.md` — full capabilities inventory
- `docs/context/DEVOS_PUBLIC_SURFACE.md` — user-facing commands and entry points
- `docs/context/DEVOS_ARCHITECTURE.md` — system architecture and component relationships
- `docs/context/codebase-map.md` — file tree with role annotations
- `docs/context/DEVOS_OWNERSHIP_AUDIT.md` — who owns what across the codebase
- `docs/context/DEVOS_DEFERRED_TOOLS.md` — deferred HTTP MCP servers
- `docs/context/DEVOS_USER_FLOWS_STALENESS.md` — user flow freshness status
- `.dev-os/runtime/context-refresh-state.json` (logical path; resolve via `scripts/lib/runtime-state.sh`)

Already indexed in managed blocks below (no need to read separately):
Skills index, Chains index, MCP index, Standards index, Workflows index
<!-- /DevOS:section:devos-context -->

<!-- DEVOS_CLAUDE_BRIEF_START -->
## Claude Operating Brief

Full guidance: `docs/context/DEVOS_PROJECT_GUIDANCE.md`

- **Project Purpose:** Define the mission and product goals.
- **Install Topology:** DevOS profile `general`; project config lives in `.dev-os/config.yml`.
- **Tech Stack:** Primary implementation language is TypeScript.
- **Development Commands:** Run tests with `pnpm run test`.
- **Architecture Anchors:** `docs/context/codebase-map.md` describes file roles and hotspots; start there.
- **Operating Rules:** Before removing or overwriting config files, create a backup first
- **Gotchas:** No gotcha signal detected yet; record traps here as they surface.
<!-- DEVOS_CLAUDE_BRIEF_END -->

<!-- DEVOS_BUNDLE_INDEX_START -->
## Framework Bundle Index

Compact framework index for low-context providers. Read the referenced bundle files for full docs.

**claude-code-core** vlatest (2.3KB) — claude code settings, permissions, CLAUDE.md, memory, CLI flags, slash commands, interactive mode, configuration
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-core@latest.json` — read `compressed_docs` field

**claude-code-extensions** vlatest (3.0KB) — hooks, skills, MCP, subagents, plugins, SKILL.md, hook events, MCP servers
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-extensions@latest.json` — read `compressed_docs` field

**claude-code-automation** vlatest (2.7KB) — headless mode, agent SDK, GitHub Actions, agent teams, CI/CD, automation, best practices, workflows
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-automation@latest.json` — read `compressed_docs` field

**claude-code-config** vlatest (3.0KB) — model config, sandboxing, checkpointing, keybindings, fast mode, status line, output styles, model aliases
> Full docs: `~/.dev-os/bundles/tier0_platform/claude-code-config@latest.json` — read `compressed_docs` field

**codex-cli** v0.137.0 (6.2KB) — codex cli, openai codex, codex exec, codex mcp, codex config, codex sandbox, AGENTS.md, @openai/codex
> Full docs: `~/.dev-os/bundles/tier0_platform/codex-cli@0.137.0.json` — read `compressed_docs` field

**github-rest-api** v2026-05 (13.7KB) — Auth & Base URL, Rate Limits, Core Endpoints (by Resource), Pagination, Error Codes, Gotchas
> Full docs: `~/.dev-os/bundles/tier2_backend/github-rest-api@2026-05.json` — read `compressed_docs` field

**linear-graphql-api** v2026-05 (?KB) — Endpoint & Authentication, Core Queries, Mutations, Pagination, Rate Limiting, Webhooks
> Full docs: `~/.dev-os/bundles/tier2_productivity/linear-graphql-api@2026-05.json` — read `compressed_docs` field

**playwright** v1.60.0 (5.8KB) — Install, Test Structure, Locators (preferred order), Actions, Assertions (web-first — auto-retry), playwright.config.ts, Auth / Storage State, Network Interception
> Full docs: `~/.dev-os/bundles/tier2_testing/playwright@latest.json` — read `compressed_docs` field

**posthog-rest-api** v2026-05 (10.6KB) — Auth & Base URLs, Rate Limits, Pagination, Events API, Persons API, Insights API, HogQL / Query API, Feature Flags API
> Full docs: `~/.dev-os/bundles/tier2_analytics/posthog-rest-api@2026-05.json` — read `compressed_docs` field

**react** v19.0.0 (13.7KB) — Hooks API reference, Server Components, Suspense and transitions
> Full docs: `~/.dev-os/bundles/tier1_core/react@19.0.0.json` — read `compressed_docs` field

**shadcn** vlatest (6.4KB) — component API and props, theming and CSS variables, Form components and validation, Dialog, Sheet, and overlay components
> Full docs: `~/.dev-os/bundles/tier1_core/shadcn@latest.json` — read `compressed_docs` field

**shadcn-ui** vlatest (8.0KB) — Core Principles, CLI (`shadcn`), components.json (project config), Theming — CSS Variables, Component Catalogue (54 UI components), Component API Pattern, Installation by Framework, Monorepo Support
> Full docs: `~/.dev-os/bundles/tier2_frontend/shadcn-ui@latest.json` — read `compressed_docs` field

**tailwindcss** v3.4.1 (7.5KB) — Utility classes reference, Responsive design, Dark mode, Custom configuration
> Full docs: `~/.dev-os/bundles/tier1_core/tailwindcss@3.4.1.json` — read `compressed_docs` field

**vitest** vv4.1.5 (17.0KB) — Install, Basic Test Structure, Test Options (v4.1+), Config (`vitest.config.ts`), Globals Mode, expect API, describe API, test.each / it.each / test.for
> Full docs: `~/.dev-os/bundles/tier2_testing/vitest@latest.json` — read `compressed_docs` field

**zod** v4.3.6 (18.0KB) — Install, Import, Core workflow: parse vs safeParse, Primitives, String validations, String formats (top-level in v4), Numbers (v4 formats), BigInt
> Full docs: `~/.dev-os/bundles/tier2_validation/zod@4.3.6.json` — read `compressed_docs` field

**zustand** v5.0.12 (8.9KB) — Core APIs, State Updates, Selectors & Re-renders, Out-of-Component Usage, Slices Pattern (large stores), Middlewares, React Context (dependency injection), TypeScript
> Full docs: `~/.dev-os/bundles/tier2_state/zustand@5.0.12.json` — read `compressed_docs` field

<!-- DEVOS_BUNDLE_INDEX_END -->

