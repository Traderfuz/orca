# Knowledge Pull Step

<!-- Shared snippet: profiles/general/workflows/_shared/knowledge/knowledge-pull-step.md -->
<!-- Reference via: {{workflows/_shared/knowledge/knowledge-pull-step}} -->
<!-- Full protocol: profiles/general/standards/global/knowledge-pull.md -->
<!-- Bash helpers: scripts/lib/fetch-docs.sh (detection, aliases, caching, known-good list) -->

Shared snippet that fetches current ecosystem knowledge before generating output. Included by `write-spec`, `create-tasks`, `implement-tasks`, `review`, and `autonomous-phases` workflows via template reference.

## When to Use

Use this step when a workflow generates output whose correctness depends on current outside knowledge: libraries, APIs, protocols, tools, frameworks, SDKs, CLIs, MCP servers, model/provider behavior, services, package managers, deployment platforms, security practices, standards, current tool behavior, or operator/user workflow guidance.

Default to running it for specs, tasks, reviews, architecture decisions, standards, documentation, workflow design, and implementation plans. Do not use it for pure local structural commands (status checks, git operations, file moves) or when an explicit knowledge waiver is passed (`--skip-knowledge-pull`, or legacy `--skip-docs`).

For feature builds, this step is only half of the preflight. Before implementation begins, the build must also cite a pinned `/architecture-creator` artifact path, usually `product/specs/<spec>/planning/architecture.md`, or record an explicit architecture waiver with a reason.

## Process

Apply the DevOS knowledge-pull standard before generating output:

1. **Detect knowledge targets** from project files (package.json, requirements.txt, go.mod, Cargo.toml, .dev-os/config.yml profile), provider/model settings, CLI/tool mentions, workflow text, standards references, and the feature description / current task statement. Deduplicate and cap at **10 candidates** (override with `DEVOS_LIBRARY_CAP` env var), prioritizing targets most central to the decision or artifact.

2. **For each candidate, run the seven-tier fallback chain** (stop at first success per target):
   - **Tier 0 — Local bundles** (fastest, free): check `.dev-os/bundles/` for a matching bundle JSON file. Read `bundle-manifest.json` to find the library name → tier/file mapping. If found, read the bundle's `compressed_docs` field for pre-compressed, versioned documentation. No MCP call needed.
   - **Tier 1 — llms.txt** (free, LLM-native): first resolve the canonical docs hostname if the library name is ambiguous or has multiple domains, then `mcp__jina-reader__llms_check(domain=<lib-domain>)` to check if the library publishes llms.txt. If found, `mcp__jina-reader__llms_fetch(domain=<lib-domain>)` for structured index, or `mcp__jina-reader__llms_fetch_full(domain=<lib-domain>, max_pages=5)` for full docs. Common domains: `nextjs.org`, `react.dev`, `tailwindcss.com`, `clerk.com`, `supabase.com`, `convex.dev`, `zod.dev`. Cap: 3 llms.txt fetches per invocation.
   - **Tier 2 — Context7** (structured, free): `mcp__context7__resolve-library-id` → `mcp__context7__query-docs` (cap: 3 calls total across all libraries)
   - **Tier 3 — LLM knowledge** (free, no MCP call): prompt the model: `"What are the current best practices and API signatures for <library> <topic> as of your knowledge cutoff? Flag anything you are uncertain about."` Proceed if high confidence; fall through if uncertain or niche/post-cutoff.
   - **Tier 4 — GitHub docs** (free): `mcp__github__get_file_contents` on the library's official repo README or docs/
   - **Tier 5 — Web scraping + Brave** (free): use when a specific doc URL is known or a free search is needed:
     - `mcp__jina-reader__read_url(url=<doc-url>)` — any URL to clean markdown
     - `mcp__crawl4ai__c4ai_scrape(url=<doc-url>)` — JS-heavy SPA doc sites (uses Playwright)
     - `mcp__brave-search__brave_llm_context(query=<query>)` — RAG-optimized chunks from Brave's 30B+ page index (free monthly quota)
     - `mcp__brave-search__brave_web_search(query=<query>)` — standard web search via Brave (free monthly quota)
   - **Tier 6 — Paid web search** (last resort, pick best fit):
     - `mcp__exa__exa_search(query=<query>, type="neural", getText=true)` — best for niche/obscure libraries, semantic understanding of intent
     - `mcp__exa__exa_answer(query="<library> <topic> current API")` — direct cited answer to specific API questions
     - `mcp__tavily__tavily_search(query="<library> <topic> current usage <year>")` — general web search
     - `mcp__perplexity__perplexity_search(query=<query>)` — quick cited web search
     - `mcp__firecrawl__fc_search(query=<query>)` — search indexed pages
   - If all seven tiers fail for a target: mark `(not found)` and continue

3. **Save a durable note by default** for each successful target under `docs/references/<target-slug>.md`. Reuse the existing note when it is fresh; refresh it when stale or when `--force-knowledge` is passed. The note must include fetched date, source tier, source URL or bundle/version, freshness, key patterns, quick reference, examples when applicable, and sources. This durable object is the future decision trace.

4. **Summarize** key current behavior, constraints, commands, signatures, patterns, or practices in working context for use during output generation. This context copy is derived from the durable note and can be compact.

5. **Prepare `knowledge_sources` entries** — one per target, recording: name, topic, date, source tier (Local bundle / llms.txt / Context7 / LLM / GitHub / Jina/Crawl4ai / Web), and durable note path.

**If `--skip-knowledge-pull` or legacy `--skip-docs` was passed:** skip this entire step and set `knowledge_sources: waived`, including the waiver reason when available.

## Output Format

Output format varies by caller — use the appropriate form:

For `spec.md` headers:
```
**knowledge_sources:**
  - <lib> — "<topic>" (<date>, Local bundle <version>)
  - <lib> — "<topic>" (<date>, llms.txt <domain>)
  - <lib> — "<topic>" (<date>, Context7 <libraryId>)
  - <lib> — "<topic>" (<date>, LLM knowledge — high confidence)
  - <lib> — "<topic>" (<date>, GitHub <org>/<repo> README)
  - <lib> — "<topic>" (<date>, Jina <url>)
  - <lib> — "<topic>" (<date>, Web <url>)
```

For `tasks.md` (comment block at top of file):
```
<!-- knowledge_sources: <lib> (Local bundle), <lib> (Context7), <lib> (LLM), <lib> (GitHub) -->
```

For review/analysis output (footnote):
```
**Knowledge sources consulted:** <lib> (Local bundle), <lib> (Context7), <lib> (LLM)
```

If no knowledge targets are detected or all tiers fail:
```
knowledge_sources: none (no current-knowledge targets detected)
```

6. **Emit telemetry** — after completing the knowledge pull (or skipping it), append one JSONL line to `product/runtime/knowledge-pull-telemetry.jsonl`:

```json
{"ts": "<ISO-8601>", "command": "<invoking command>", "targets": ["<target1>", "<target2>"], "tiers_hit": {"<target1>": "local_bundle", "<target2>": "context7"}, "durable_notes": {"<target1>": "docs/references/<target1>.md"}, "skipped": false, "all_failed": []}
```

If `--skip-knowledge-pull` or legacy `--skip-docs` was passed: `{"ts": "<ISO-8601>", "command": "<invoking command>", "skipped": true, "waiver": "<reason if known>"}`

This telemetry enables the designer feedback loop — tier hit rates, failure patterns, and skip frequency are reviewable via `monthly-retro`.
