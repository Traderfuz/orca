# Task List Creation

## When to Use

Run this workflow after `spec.md` is complete and architect review has been performed. Use it to create the ordered `tasks.md` file for a spec before implementation begins.

Do not run this workflow before spec.md exists, or on specs that already have a complete tasks.md with active implementation in progress.

## Core Responsibilities

1. **Analyze spec and requirements**: Read and analyze the spec.md and/or requirements.md to inform the tasks list you will create.
2. **Run pre-implementation reviews**: Perform architect and process optimization reviews before creating tasks.
3. **Plan task execution order**: Break the requirements into a list of tasks in an order that takes their dependencies into account.
4. **Group tasks by specialization**: Group tasks that require the same skill or stack specialization together (backend, api, ui design, etc.)
5. **Create Tasks list**: Create the markdown tasks list broken into groups with sub-tasks.

## Wave State

When invoked from `autonomous`, update `.dev-os/runtime/session-state.yml` at the start and end of this workflow:

**On entry (before Step 0):**
```yaml
wave_phase: create-tasks
wave_goal: "Generate executable tasks.md from approved spec"
wave_scope_claims:
  - "product/specs/<slug>/tasks.md"
  - "product/specs/<slug>/planning/architect-review.md (read)"
  - "product/specs/<slug>/planning/process-optimizer-review.md (read)"
wave_status: running
```

**On completion (after Step 5):**
```yaml
wave_phase: create-tasks
wave_status: complete
discovery_summary: "tasks.md written — <N> tasks in <M> groups"
next_wave_goal: "implement-tasks: execute tasks in dependency order"
```

When invoked directly via `create-tasks` (not from autonomous), skip the wave-state update — session-state.yml is not required.

## Workflow

### Step 0: Knowledge Pull

<!-- per profiles/general/standards/global/knowledge-pull.md -->

{{workflows/_shared/knowledge/knowledge-pull-step}}

After the knowledge pull, add a comment block at the very top of `tasks.md` (before all other content):
```
<!-- knowledge_sources: <lib> (<tier>), <lib> (<tier>), ... -->
```
If no libraries were detected: `<!-- knowledge_sources: none (no libraries detected) -->`

### Step 1: Analyze Spec & Requirements

Read each of these files (whichever are available) and analyze them to understand the requirements for this feature implementation:
- `product/specs/[this-spec]/spec.md`
- `product/specs/[this-spec]/planning/requirements.md`

Use your learnings to inform the reviews and tasks list you will create.

### Step 1b: Frontend Scope Check

{{workflows/_shared/skills/frontend-scope-detection}}

Run this check after reading the spec and requirements, but before the pre-implementation reviews and task grouping.

**If `frontend_scope = true` and the frontend-design skill was already loaded earlier in the session:** confirm it is still active in context rather than fully re-loading.

**If `frontend_scope = true` (skill active):**
- keep UI/design task groups explicit in the tasks breakdown
- carry the named aesthetic direction into task ordering and acceptance criteria where relevant
- ensure the resulting `tasks.md` references the frontend-design skill in implementation notes when the slice includes UI work

### Step 1c: Source Reality Check

Before creating any tasks, verify that the gaps and requirements in the spec are not already
implemented in source files. Writing tasks for already-fixed issues wastes implementation cycles
and creates false "done" accounting.

{{workflows/implementation/source-reality-check}}

**Skip condition:** Pass `--skip-source-check` or set `skip_source_check: true` in the session if this
is a refactor spec or source check was already run in this session.

After the check, use the results to prune tasks in Step 4:
- Exclude tasks for claims marked `exists`
- Add notes to tasks for claims marked `partial`
- Keep all tasks for claims marked `missing`

### Step 2: Pre-Implementation Reviews

Before creating tasks, run these reviews to catch issues while changes are still cheap:

**Skip condition:** When `planning/architect-review.md` AND `planning/process-optimizer-review.md` already exist in this spec's planning directory (written by `autonomous` phases 5+6 earlier in this session), skip running new reviews. Instead, read the existing review files and extract their findings summary for the Step 2 display block. Only run full reviews when invoked directly via `create-tasks` without a prior autonomous session.

#### Architect Review

Perform an architectural review of the specification:

{{workflows/architecture/architect-review}}

Note: Architectural findings are WARNINGS ONLY. Critical issues should ideally be addressed in the spec before proceeding.

#### Process Optimization Review

Analyze the proposed workflow for inefficiencies:

{{workflows/optimization/process-optimizer-review}}

Note: Process recommendations are SUGGESTIONS ONLY. Consider addressing high-impact items in the spec before proceeding.

#### Review Summary

After completing both reviews, output a summary:

```
📋 Pre-Implementation Reviews Complete

🏛️ Architect Review:
- Impact: [High/Medium/Low]
- Findings: [X critical, X high, X medium, X low]
- Report: product/specs/[spec]/planning/architect-review.md

⚡ Process Optimization Review:
- Gaps identified: [X]
- Optimizations proposed: [X]
- Report: product/specs/[spec]/planning/process-optimizer-review.md

[If critical issues found]
⚠️ Critical findings detected. Consider updating the spec before creating tasks.

[If no critical issues]
✅ No blocking issues. Proceeding to task creation.
```

### Step 3: MVP Priority Detection

Detect and label task priorities before creating the breakdown:

{{workflows/implementation/mvp-detect}}

This analyzes the spec to identify:
- **P1 (MVP)**: Core user journey tasks (~40%)
- **P2 (Important)**: Enhancement tasks (~35%)
- **P3 (Nice-to-have)**: Polish tasks (~25%)

Priority labels will be added to tasks as comments: `(P1)`, `(P2)`, `(P3)`

### Step 4: Create Tasks Breakdown

Generate `product/specs/[current-spec]/tasks.md`.

**Important**: The exact tasks, task groups, and organization will vary based on the feature's specific requirements. The following is an example format - adapt the content of the tasks list to match what THIS feature actually needs.

**Canonical checkbox format** — all tasks MUST use bullet-list checkboxes:
- Unchecked: `- [ ] N.N description`
- Checked: `- [x] N.N description`

Do NOT use the legacy inline header format (`### Task N.N — ~~description~~ [x]`). That format is not parseable by `project-status`, triage, or automated progress detection. Only the `- [ ]` / `- [x]` bullet format is greppable and machine-readable.

```markdown
# Task Breakdown: [Feature Name]

## Overview
Total Tasks: [count]

## Task List

### Database Layer

#### Task Group 1: Data Models and Migrations
**Dependencies:** None

- [ ] 1.0 Complete database layer
  - [ ] 1.1 Write 2-8 focused tests for [Model] functionality
    - Limit to 2-8 highly focused tests maximum
    - Test only critical model behaviors (e.g., primary validation, key association, core method)
    - Skip exhaustive coverage of all methods and edge cases
  - [ ] 1.2 Create [Model] with validations
    - Fields: [list]
    - Validations: [list]
    - Reuse pattern from: [existing model if applicable]
  - [ ] 1.3 Create migration for [table]
    - Add indexes for: [fields]
    - Foreign keys: [relationships]
  - [ ] 1.4 Set up associations
    - [Model] has_many [related]
    - [Model] belongs_to [parent]
  - [ ] 1.5 Ensure database layer tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify migrations run successfully
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- Models pass validation tests
- Migrations run successfully
- Associations work correctly

### API Layer

#### Task Group 2: API Endpoints
**Dependencies:** Task Group 1

- [ ] 2.0 Complete API layer
  - [ ] 2.1 Write 2-8 focused tests for API endpoints
    - Limit to 2-8 highly focused tests maximum
    - Test only critical controller actions (e.g., primary CRUD operation, auth check, key error case)
    - Skip exhaustive testing of all actions and scenarios
  - [ ] 2.2 Create [resource] controller
    - Actions: index, show, create, update, destroy
    - Follow pattern from: [existing controller]
  - [ ] 2.3 Implement authentication/authorization
    - Use existing auth pattern
    - Add permission checks
  - [ ] 2.4 Add API response formatting
    - JSON responses
    - Error handling
    - Status codes
  - [ ] 2.5 Ensure API layer tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify critical CRUD operations work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- All CRUD operations work
- Proper authorization enforced
- Consistent response format

### Frontend Components

#### Task Group 3: UI Design
**Dependencies:** Task Group 2

- [ ] 3.0 Complete UI components
  - [ ] 3.1 Write 2-8 focused tests for UI components
    - Limit to 2-8 highly focused tests maximum
    - Test only critical component behaviors (e.g., primary user interaction, key form submission, main rendering case)
    - Skip exhaustive testing of all component states and interactions
  - [ ] 3.2 Create [Component] component
    - Reuse: [existing component] as base
    - Props: [list]
    - State: [list]
  - [ ] 3.3 Implement [Feature] form
    - Fields: [list]
    - Validation: client-side
    - Submit handling
  - [ ] 3.4 Build [View] page
    - Layout: [description]
    - Components: [list]
    - Match mockup: `product/specs/[spec]/planning/visuals/[file]`
  - [ ] 3.5 Apply base styles
    - Follow existing design system
    - Use variables from: [style file]
  - [ ] 3.6 Implement responsive design
    - Mobile: 320px - 768px
    - Tablet: 768px - 1024px
    - Desktop: 1024px+
  - [ ] 3.7 Add interactions and animations
    - Hover states
    - Transitions
    - Loading states
  - [ ] 3.8 Ensure UI component tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify critical component behaviors work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- Components render correctly
- Forms validate and submit
- Matches visual design

### Testing

#### Task Group 4: Test Review & Gap Analysis
**Dependencies:** Task Groups 1-3

- [ ] 4.0 Review existing tests and fill critical gaps only
  - [ ] 4.1 Review tests from Task Groups 1-3
    - Review the 2-8 tests written by database-engineer (Task 1.1)
    - Review the 2-8 tests written by api-engineer (Task 2.1)
    - Review the 2-8 tests written by ui-designer (Task 3.1)
    - Total existing tests: approximately 6-24 tests
  - [ ] 4.2 Analyze test coverage gaps for THIS feature only
    - Identify critical user workflows that lack test coverage
    - Focus ONLY on gaps related to this spec's feature requirements
    - Do NOT assess entire application test coverage
    - Prioritize end-to-end workflows over unit test gaps
  - [ ] 4.3 Write up to 10 additional strategic tests maximum
    - Add maximum of 10 new tests to fill identified critical gaps
    - Focus on integration points and end-to-end workflows
    - Do NOT write comprehensive coverage for all scenarios
    - Skip edge cases, performance tests, and accessibility tests unless business-critical
  - [ ] 4.4 Run feature-specific tests only
    - Run ONLY tests related to this spec's feature (tests from 1.1, 2.1, 3.1, and 4.3)
    - Expected total: approximately 16-34 tests maximum
    - Do NOT run the entire application test suite
    - Verify critical workflows pass

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 16-34 tests total)
- Critical user workflows for this feature are covered
- No more than 10 additional tests added when filling in testing gaps
- Testing focused exclusively on this spec's feature requirements

## Execution Order

Recommended implementation sequence:
1. Database Layer (Task Group 1)
2. API Layer (Task Group 2)
3. Frontend Design (Task Group 3)
4. Test Review & Gap Analysis (Task Group 4)
```

**Note**: Adapt this structure based on the actual feature requirements. Some features may need:
- Different task groups (e.g., email notifications, payment processing, data migration)
- Different execution order based on dependencies
- More or fewer sub-tasks per group

## Step 5: User Flows Documentation Check

After generating the tasks breakdown, check for `docs/user-flows.md` and inject an appropriate task group.

**Check:**
```bash
if [ -f "docs/user-flows.md" ]; then
    user_flows_exists=true
else
    user_flows_exists=false
fi
```

**Decision logic:**

1. `docs/user-flows.md` does **not** exist → append **Template A** (full create task group) from `{{workflows/documentation/user-flows-standard}}` to tasks.md. Label it P2, dependencies = all other task groups.

2. `docs/user-flows.md` exists AND this spec introduces new user-facing commands, workflows, or pipelines → append **Template B** (update task) from `{{workflows/documentation/user-flows-standard}}` to tasks.md.

3. `docs/user-flows.md` exists AND the spec is a purely internal change (no new pipelines) → skip. Do not add any user-flows task.

When injecting, replace `N` in the template with the next available task group number.

## Important Constraints

- **Create tasks that are specific and verifiable**
- **Group related tasks:** For example, group back-end engineering tasks together and front-end UI tasks together.
- **Limit test writing during development**:
  - Each task group (1-3) should write 2-8 focused tests maximum
  - Tests should cover only critical behaviors, not exhaustive coverage
  - Test verification should run ONLY the newly written tests, not the entire suite
  - If there is a dedicated test coverage group for filling in gaps in test coverage, this group should add only a maximum of 10 additional tests IF NECESSARY to fill critical gaps
- **Use a focused test-driven approach** where each task group starts with writing 2-8 tests (x.1 sub-task) and ends with running ONLY those tests (final sub-task)
- **Include acceptance criteria** for each task group
- **Reference visual assets** if visuals are available

## Display Format

```
Task list created: product/specs/[spec-name]/tasks.md
  Groups:     [N] task groups
  Tasks:      [N] total tasks
  Open:       [N] remaining
  Next: implement-tasks --spec [spec-name]
```
