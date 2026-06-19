# Project Health Audit Workflow

Run a profile-aware project health audit combining static analysis and optional runtime browser validation to detect orphaned components, dead code, missing states, and profile-specific issues. Runtime browser validation follows `profiles/general/standards/global/browser-review-policy.md`; reports include selected driver, selected target, auth path, backend, artifact paths, and fallback reason.

## When to Use

Use this workflow when:

- validating overall project health before release,
- auditing profile-specific concerns (CLI argument safety, PWA manifest compliance, business SEO, etc.),
- detecting dead code, broken imports, and unused exports,
- running browser-based validation of interactive elements,
- or when `project-health-audit` is invoked.


Do not use this workflow during active implementation — it is a maintenance check. For targeted implementation verification, use `verify` instead.

## Profile Behavior

The audit automatically detects the active DevOS profile from `.dev-os/config.yml` and loads the corresponding audit plugin chain. You can override with `--profile <name>`.

### Profile Plugin Chain

Each profile inherits from its parent. The audit runs all plugins in the chain from root to leaf:

| Profile | Chain | Key Checks |
| --- | --- | --- |
| `default` | default | Type safety, error handling, code organization, tooling |
| `general` | default -> general | + Docs drift, test coverage, git hygiene, dependency health |
| `cli` | default -> general -> cli | + Dead commands, argument gaps, error paths, auth flows |
| `webapp` | default -> general -> webapp | + Orphaned components, dead handlers, missing states, forms |
| `business` | default -> general -> business | + SEO meta, sitemap coverage, content wiring |
| `pwa` | default -> general -> pwa | + Manifest compliance, service worker, cache strategy, offline |

### Health Score Categories

Each profile defines its own weighted categories. The composite score is calculated from all category scores weighted by the profile's configuration.

## Input

- Project root directory (defaults to current working directory).
- Optional `--profile <name>` to override auto-detection.
- Optional `--scope static|runtime|full` to limit scope (default: full).
- Optional `--fix` to generate fix task files.
- Optional `--resume` to continue from a previous interrupted run.

## Output Artifacts

All output is written to `.dev-os/health-audit/<run-id>/`:

- `static/` — Static analysis JSON findings per detection type
- `runtime/` — Runtime validation JSON results (routes, forms, dead clicks)
- `summary.json` — Machine-readable composite score, grade, and findings
- `summary.md` — Human-readable report with category breakdown
- `fix-tasks.md` — Generated fix tasks (when `--fix` is used)
- `run-metadata.json` — Run configuration and timing
- `checkpoint.json` — Resume checkpoint (auto-managed)

Historical scores are appended to `.dev-os/health-audit/history.json`.

## Phase Map

### Phase 1: Static Analysis

1. Run base detections (broken imports, dead handlers, unused exports).
2. Run profile-specific detections from the plugin chain.
3. Write findings to `static/` directory as individual JSON files.

### Phase 2: Runtime Validation (when scope includes runtime)

> **For full user journey testing, use `e2e` instead.** This phase covers structural
> health (dead clicks, JS errors, broken forms across all routes). `e2e` provides
> deeper coverage: parallel research, DB validation, per-journey task tracking, and responsive
> testing. The two are complementary — health-audit for breadth, `e2e` for depth.

1. Start the development server.
2. Discover routes from the project file system.
3. Visit each route with `agent-browser`, checking for:
   - JavaScript errors and console warnings
   - Dead click targets (buttons/links with no response)
   - Form submission behavior
4. Write results to `runtime/` directory.

### Phase 3: Scoring

1. Load profile-specific weight categories from the plugin chain.
2. Calculate per-category scores from findings.
3. Compute weighted composite score (0-100).
4. Assign grade: Healthy (90+), Needs attention (70-89), Degraded (50-69), Critical (<50).
5. Write `summary.json` and `summary.md`.

### Phase 4: Fix Generation (when --fix is used)

1. Load profile-specific fix templates from the plugin chain.
2. Match findings to templates.
3. Generate actionable fix tasks in `fix-tasks.md`.

## Verification Gate

After running the audit:

- Review findings by severity (CRITICAL > HIGH > MEDIUM > LOW).
- Address CRITICAL findings before any deployment.
- Re-run with `--resume` if interrupted mid-audit.
- Compare scores against historical trends in `history.json`.

## Report Format

The `summary.md` report includes:

- Overall health score and grade
- Per-category scores with visual progress bars
- Findings count by severity
- Recommended next steps

## Notes

- Static-only runs (`--scope static`) complete quickly without a dev server.
- Runtime runs require the project's dev server to be startable.
- The `--resume` flag skips already-completed phases and routes from a previous run.
- Plugin detections are additive — each profile in the chain adds its own checks on top of inherited ones.
- Webapp-specific detections (orphaned components, missing route states, skeleton mismatches, dead links, incomplete forms) only run when the profile is `webapp` or unspecified.
