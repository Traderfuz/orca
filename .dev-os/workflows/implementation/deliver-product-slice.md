# Deliver Product Slice Workflow

Turn a product goal or gap into a production-ready implementation slice through one continuous sequence: assess the gap, shape the spec, create tasks, implement end to end, verify, and sync the project truth sources.

This workflow is for real application development where the outcome must be usable in the live product, not just documented or partially scaffolded.

Default scope is the current repository/project in the active workspace. A goal string may mention another project as an example, but that does not change the target unless the user explicitly says to switch projects.

## When to Use

Use this workflow when:
- a user wants to keep moving from idea or gap directly into shipping-quality implementation
- a feature area needs to be closed end to end instead of split into disconnected planning and coding passes
- the right next step is not a one-off fix, but a full product slice: workflow, UI, contracts, verification, and backlog sync
- you are operating in autonomous mode and need a deterministic loop for “keep going until this slice is genuinely usable”

Do not use this workflow when:
- the user only wants brainstorming, option exploration, or architecture discussion without implementation
- the task is a narrow bug fix that does not require spec/task reshaping
- the work is purely documentation creation or purely design exploration
- the request is for a specialist artifact only (use `bx-skill-creator`, `bx-agent-creator`, or `bx-standards-creator` for those)

## Process

1. **Read project truth sources first**
   - Read the root `CLAUDE.md`, `AGENTS.md`, and any project-local instructions that govern the current area.
   - Read `product/specs/feature-backlog.md` before planning or implementing.
   - Check whether an active spec/task package already exists for the feature area.

2. **Run gap analysis on the real workflow** (`gap-analysis --mode 6 --converge`)
   - Default: Mode 6 (Multi-Angle) with convergence — cross-references process gaps, codebase wiring, and friction.
   - Audit the current user flow and operator flow, not just isolated code.
   - Identify where the product is incomplete, confusing, dead-ended, or only partially wired.
   - Treat intended missing capability as implementation debt, not as a reason to shrink the promise.
   - All gaps are closed — no severity-based exemptions. The convergence loop re-analyzes until 0 new gaps per pass.
   - Write findings to `product/gap-analysis/` and append entries to `product/gap-analysis/gap-registry.jsonl`.

2b. **Frontend scope check before planning**
   - If the slice is frontend-scoped, load the shared frontend design pipeline before shaping the spec or tasks.
   - Reuse the same detection logic as `write-spec` and `implement-tasks` so frontend work always gets the `frontend-design` skill in context.
   - If the skill was already loaded earlier in the session, confirm it is still active rather than reloading it redundantly.
   - Shared snippet: `{{workflows/_shared/skills/frontend-scope-detection}}`

3. **Shape the feature as a full slice**
   - Convert the gap findings into a real spec with clear goals, non-goals, and end-to-end scope.
   - Default to full feature posture: contracts, data path, backend logic, UI/workflow, handoff, and verification.
   - If a capability is intended but missing, add it to the spec and tasks rather than removing it from scope.

4. **Create implementation tasks in execution order**
   - Break the slice into ordered task groups with real dependencies.
   - Make each group independently verifiable.
   - Include product-level verification tasks, not only code tasks.
   - Update `feature-backlog.md` so the spec status matches reality.

5. **Implement the slice end to end**
   - Start with the highest-leverage live path, not helper abstractions in isolation.
   - Wire the actual product surfaces the user touches.
   - Prefer the real execution surfaces over parallel or legacy UI shells.
   - If the work spans multiple areas, keep one coherent loop: data model -> API/actions -> UI -> operator path.

6. **Close the product loop, not just the code loop**
   - Seed realistic example data or artifacts where the feature would otherwise be empty or untestable.
   - Add missing lifecycle, gating, status, and empty-state behavior if they block real use.
   - Ensure related surfaces reflect the new capability consistently.

6a. **Polish the slice before verification**
   - If the diff contains obvious AI slop, run `polish` on the changed files before the final verification pass.
   - For frontend/UI slices, run `ui-review` on the live URL or a representative screenshot before final approval.

7. **Verify before claiming completion**
   - Run targeted tests for the changed feature area.
   - Run typecheck.
   - Run production build.
   - For substantial slices, run `harden` as the canonical test → typecheck → build → validate loop instead of ad hoc repeated checks.
   - If the slice touches auth, access control, secrets, shell execution, or external inputs, run `security-review` before sync.
   - If verification fails, diagnose and fix before moving on.
   - Do not claim the slice is complete while routes dead-end, lists are empty with no seed path, or required follow-through actions are missing.

7b. **Review Phase (post-implementation, before sync)**

   Run each step in sequence after implement-tasks completes. Skip conditional steps when their prerequisite is absent.

   **Step R0 — URL pre-collection (before any review steps):**
   - Check `.dev-os/config.yml` for `preview_url` or `dev_url` field.
   - If not found: prompt ONCE before the review sequence starts:
     ```
     Enter the URL for ui-design-qa --mode verify screenshots (or press Enter to skip):
     ```
   - If no URL provided: note "ui-review/ui-design-qa --mode verify will be skipped (no URL available)" and continue.

   **Step R1 — Code Review (always):**
   - Run `review`
   - Produces: `product/reviews/<spec>-review-YYYY-MM-DD.md`

   **Step R2 — Validate (always):**
   - Run `predeploy-check`
   - Checks: auth, secrets, build health, TypeScript

   **Step R3 — Design Check / Verify (conditional):**
   - Condition: frontend/UI changes exist
   - If a live URL or screenshot is available: run `ui-review --spec <spec> --url <url>` as the iterative visual review step
   - Condition for final pixel-level confirmation: `.dev-os/state/design-preview-approved.html` exists AND URL was collected in R0
   - If both conditions met: run `ui-design-qa --mode verify --spec <spec> --url <url>`
   - If HTML absent: print "`.dev-os/state/design-preview-approved.html` not found — skipping ui-design-qa --mode verify. Run `consume-design` to generate it."
   - If URL absent: print "No URL provided — skipping ui-design-qa --mode verify."

   **Step R4 — Handoff Fidelity (conditional — fires inside review):**
   - Condition: `.dev-os/state/marketing-handoff.json` or `.dev-os/state/creative-handoff.json` exists
   - `review` includes a Handoff Fidelity section automatically when state files are present.
   - Print fidelity coverage from the review output (N/10 strings matched).

   **Step R5 — E2E Tests (conditional):**
   - Condition: `--skip-e2e` flag not passed
   - Run `e2e`

   **Review Summary** — after all steps complete:
   ```
   Review Phase Complete
   ─────────────────────────────────────────────
   ✓  Code review    → product/reviews/<spec>-review-YYYY-MM-DD.md
   ✓  Validate       → pass
   ✓/— Design check   → pass / skipped (reason)
   ✓/— Design verify  → pass / skipped (reason)
   ✓/— Fidelity      → N/10 strings matched / skipped
   ✓/— E2E           → pass / skipped
   ─────────────────────────────────────────────
   ```

   **--skip-gap-analysis guard:**
   When `--skip-gap-analysis` is passed, first check whether `planning/gap-analysis-report.md` exists for the current spec.
   - If **not found**: display warning and stop:
     ```
     WARNING: --skip-gap-analysis passed but no gap analysis report found.
     Gap analysis has not been run for this spec.

     To proceed: pass --force-skip-gap-analysis (override, skip without a report)
     To run gap analysis: remove --skip-gap-analysis flag
     ```
   - If **found**: skip gap analysis (report already present from previous run).
   - `--force-skip-gap-analysis` overrides the guard unconditionally.

8. **Sync project truth sources**
   - Update `tasks.md` checkboxes to reflect what is actually implemented.
   - Update backlog/spec status if the slice moved forward materially.
   - Run `user-facing-docs` when the feature introduces reader-facing workflows, public commands, APIs, onboarding paths, seeds, operator procedures, or recovery paths.
   - Add or update the docs package before running `docs-sync`.
   - Summarize what remains in the current slice so the next autonomous pass starts from the true state.

## Display Format

Use this structure when reporting progress or completion:

```text
=== Deliver Product Slice ===

Area:       <feature area>
Objective:  <what became usable>
Status:     <gap analysis | spec'd | implementing | verified | complete>

Completed
- <implemented capability>
- <implemented capability>
- <implemented capability>

Verified
- <targeted tests>
- <typecheck>
- <build>

Remaining
- <next highest-value gap in this same slice>
- <next highest-value gap in this same slice>
```

## Notes

- This workflow is the right abstraction for the pattern we used today: gap-analysis -> shape-spec -> create-tasks -> implement -> verify -> sync.
- Frontend slices must always route through the shared frontend scope detector so the `frontend-design` skill is in context before spec shaping and task execution.
- A **workflow** is the correct DevOS artifact for this because the reusable value is the operating sequence.
- A **skill** would be appropriate for one specialized step inside this workflow, such as writing standards, generating seeds, or reviewing UI.
- An **agent** would be appropriate only if you want a dedicated autonomous role prompt that executes this workflow repeatedly.
