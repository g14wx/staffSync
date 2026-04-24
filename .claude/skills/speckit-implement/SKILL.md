---
name: "speckit-implement"
description: "Execute the implementation plan by processing and executing all tasks defined in tasks.md"
argument-hint: "Optional implementation guidance or task filter"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/implement.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before implementation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_implement` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}
    
    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Outline

1. Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Check checklists status** (if FEATURE_DIR/checklists/ exists):
   - Scan all checklist files in the checklists/ directory
   - For each checklist, count:
     - Total items: All lines matching `- [ ]` or `- [X]` or `- [x]`
     - Completed items: Lines matching `- [X]` or `- [x]`
     - Incomplete items: Lines matching `- [ ]`
   - Create a status table:

     ```text
     | Checklist | Total | Completed | Incomplete | Status |
     |-----------|-------|-----------|------------|--------|
     | ux.md     | 12    | 12        | 0          | ✓ PASS |
     | test.md   | 8     | 5         | 3          | ✗ FAIL |
     | security.md | 6   | 6         | 0          | ✓ PASS |
     ```

   - Calculate overall status:
     - **PASS**: All checklists have 0 incomplete items
     - **FAIL**: One or more checklists have incomplete items

   - **If any checklist is incomplete**:
     - Display the table with incomplete item counts
     - **STOP** and ask: "Some checklists are incomplete. Do you want to proceed with implementation anyway? (yes/no)"
     - Wait for user response before continuing
     - If user says "no" or "wait" or "stop", halt execution
     - If user says "yes" or "proceed" or "continue", proceed to step 3

   - **If all checklists are complete**:
     - Display the table showing all checklists passed
     - Automatically proceed to step 3

2a. **Resolve Trello card and post start comment**: Run `## Trello Integration` § A below before loading implementation context. If no card is resolvable, continue without blocking but record that Trello sync is disabled for this run.

3. Load and analyze the implementation context:
   - **REQUIRED**: Read tasks.md for the complete task list and execution plan
   - **REQUIRED**: Read plan.md for tech stack, architecture, and file structure
   - **IF EXISTS**: Read data-model.md for entities and relationships
   - **IF EXISTS**: Read contracts/ for API specifications and test requirements
   - **IF EXISTS**: Read research.md for technical decisions and constraints
   - **IF EXISTS**: Read quickstart.md for integration scenarios

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `*.dll`, `autom4te.cache/`, `config.status`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. Parse tasks.md structure and extract:
   - **Task phases**: Setup, Tests, Core, Integration, Polish
   - **Task dependencies**: Sequential vs parallel execution rules
   - **Task details**: ID, description, file paths, parallel markers [P]
   - **Execution flow**: Order and dependency requirements

6. Execute implementation following the task plan:
   - **Phase-by-phase execution**: Complete each phase before moving to the next
   - **Respect dependencies**: Run sequential tasks in order, parallel tasks [P] can run together  
   - **Follow TDD approach**: Execute test tasks before their corresponding implementation tasks
   - **File-based coordination**: Tasks affecting the same files must run sequentially
   - **Validation checkpoints**: Verify each phase completion before proceeding

7. Implementation execution rules:
   - **Setup first**: Initialize project structure, dependencies, configuration
   - **Tests before code**: If you need to write tests for contracts, entities, and integration scenarios
   - **Core development**: Implement models, services, CLI commands, endpoints
   - **Integration work**: Database connections, middleware, logging, external services
   - **Polish and validation**: Unit tests, performance optimization, documentation

8. Progress tracking and error handling:
   - Report progress after each completed task
   - Halt execution if any non-parallel task fails
   - For parallel tasks [P], continue with successful tasks, report failed ones
   - Provide clear error messages with context for debugging
   - Suggest next steps if implementation cannot proceed
   - **IMPORTANT** For completed tasks, make sure to mark the task off as [X] in the tasks file.
   - **Trello sync (per task)**: Immediately after marking a task `[X]` in tasks.md, run `## Trello Integration` § B (toggle matching checklist item to `complete` + post progress comment). If Trello sync is disabled for this run, skip silently.
   - **Trello sync (mid-task)**: For long-running or multi-file tasks, post interim comments via `## Trello Integration` § B at meaningful checkpoints (file scaffolded, migration written, handler wired, tests passing). Keep each comment compact — one task per comment, bullets over prose.

9. Completion validation:
   - Verify all required tasks are completed
   - Check that implemented features match the original specification
   - Validate that tests pass and coverage meets requirements
   - Confirm the implementation follows the technical plan
   - Report final status with summary of completed work
   - **Trello sync (final)**: Run `## Trello Integration` § C (post completion comment with branch name, commit SHAs, files touched, public surface added, follow-ups). Skip silently if Trello sync disabled.

Note: This command assumes a complete task breakdown exists in tasks.md. If tasks are incomplete or missing, suggest running `/speckit.tasks` first to regenerate the task list.

10. **Check for extension hooks**: After completion validation, check if `.specify/extensions.yml` exists in the project root.
    - If it exists, read it and look for entries under the `hooks.after_implement` key
    - If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
    - Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
    - For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
      - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
      - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
    - When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
    - For each executable hook, output the following based on its `optional` flag:
      - **Optional hook** (`optional: true`):
        ```
        ## Extension Hooks

        **Optional Hook**: {extension}
        Command: `/{command}`
        Description: {description}

        Prompt: {prompt}
        To execute: `/{command}`
        ```
      - **Mandatory hook** (`optional: false`):
        ```
        ## Extension Hooks

        **Automatic Hook**: {extension}
        Executing: `/{command}`
        EXECUTE_COMMAND: {command}
        ```
    - If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Trello Integration

Purpose: mirror implementation progress on the Trello card originally referenced during `/speckit.specify`. Keep the card's checklists and comment stream authoritative so reviewers/stakeholders can follow progress without reading the repo.

**Tools used** (Trello MCP):
- `mcp__trello__set_active_board` / `mcp__trello__set_active_workspace` (only if card not reachable on default active board)
- `mcp__trello__get_card`
- `mcp__trello__get_checklist_items`
- `mcp__trello__find_checklist_items_by_description`
- `mcp__trello__update_checklist_item`
- `mcp__trello__add_checklist_item` (only if a tasks.md item has no matching checklist entry and auto-create is enabled — see § D)
- `mcp__trello__create_checklist` (same condition)
- `mcp__trello__add_comment`

Do **not** use Trello tools to move, archive, assign, or relabel the card. Progress sync is read-only w.r.t. card metadata; the only writes allowed are: toggle checklist items, add checklist items (with user opt-in), add comments.

### § A — Resolve Trello card and post start comment

1. **Resolve the card ID** in this order (first match wins):
   a. `.specify/feature.json` → key `trello_card_id` (preferred; populated by `/speckit.specify` or manually).
   b. `.specify/feature.json` → key `trello_card_url` → extract card ID from the URL shape `https://trello.com/c/<cardId>[/<slug>]`.
   c. `SPEC_FILE` (spec.md) frontmatter: `trello_card_id:` or `trello_card_url:`.
   d. First `https://trello.com/c/<id>` URL found in spec.md body.
   e. If none of the above: ask the user once — "No Trello card linked to this feature. Paste card URL/ID to enable Trello sync, or type `skip` to proceed without it." If they type `skip`, set Trello sync to **disabled** for this run and continue. If they paste a URL/ID, persist it to `.specify/feature.json` under `trello_card_id` for future runs.
2. **Verify reachability**: call `mcp__trello__get_card` with the resolved ID. If it fails (card not found, 401/403, active board mismatch):
   - Try `mcp__trello__list_boards` → if the card's board is in the list, `mcp__trello__set_active_board` then re-try once.
   - If still failing, warn the user with the exact error and set Trello sync to **disabled** for this run. Do not halt implementation.
3. **Post the start comment** via `mcp__trello__add_comment`. Template:

   ```
   🤖 Implementation started — `/speckit.implement`

   - Feature dir: <FEATURE_DIR relative to repo root>
   - Branch: <current git branch>
   - Spec: <SPEC_FILE>
   - Tasks: <N total> (<S setup> / <T tests> / <C core> / <I integration> / <P polish>)
   - Started at: <ISO-8601 timestamp, UTC>

   Will toggle checklist items and post progress comments as phases complete.
   ```

4. Store the resolved `trello_card_id` in memory for this run so §§ B and C can reuse it without re-resolving.

### § B — Toggle checklist item + post progress comment (per task)

Run after marking a task `[X]` in tasks.md, and for mid-task checkpoints on long tasks.

1. **Match the tasks.md item to a Trello checklist item**:
   - Load checklists via `mcp__trello__get_card` (with `includeChecklists: true` if supported) or `mcp__trello__get_checklist_items`.
   - Match on task ID prefix first (e.g. `T042`), then on exact task description, then on normalized substring (lowercase, whitespace-collapsed).
   - If multiple candidates match, prefer the one whose checklist name equals the tasks.md phase (e.g. "Core", "Tests").
2. **If no match**:
   - If auto-create is enabled (§ D), call `mcp__trello__add_checklist_item` under the checklist named after the task's phase; create the checklist first via `mcp__trello__create_checklist` if missing. Then proceed to toggle.
   - If auto-create is disabled, skip toggle and note the miss in the progress comment body.
3. **Toggle to complete**: `mcp__trello__update_checklist_item` with state `complete` (exact field name per the MCP tool schema — `state: "complete"` or `checked: true`, whichever the tool accepts). Never toggle an item back to incomplete except to correct a sync error.
4. **Post the progress comment**. Choose template by checkpoint type:

   **Task complete:**
   ```
   ✅ <T0XX> <task description> — done

   - Files: `path/a.cs`, `path/b.cs`
   - Key additions: `Namespace.ClassName.MethodName(...)`, handler `CreateEmployeeCommandHandler`, validator `CreateEmployeeValidator`
   - Variables/config: `appsettings.json:ConnectionStrings:StaffDb`
   - Commit: `<short SHA>` "<commit subject>"  (or "not yet committed" if deferred)
   - Next: T0XX+1 <next task description>
   ```

   **Mid-task update** (e.g. migration written but handler pending):
   ```
   🔧 <T0XX> <task description> — in progress

   - Done: migration `20260423_AddEmployeeTable.sql`, repository `EmployeeReadRepository.ListAsync`
   - Pending: handler wiring, endpoint mapping
   - Files touched so far: `...`
   ```

   **Task blocked/failed:**
   ```
   ⚠️ <T0XX> <task description> — blocked

   - Error: <short quote of the actual error message>
   - Root cause: <one-line hypothesis>
   - Next action: <what will unblock it>
   ```

5. Omit sections that are empty. Keep comments compact — bullets over prose. Quote file paths with backticks. Never paste secrets, connection strings with credentials, or PII into comments.

### § C — Completion comment

Post once, after all tasks are `[X]` and completion validation passes. Template:

```
🎉 Implementation complete — <feature short name>

- Branch: `<branch name>`
- Commits (in order):
  - `<sha1>` — <subject>
  - `<sha2>` — <subject>
- Tasks: <N>/<N> complete
- Files added: <count>, modified: <count>, deleted: <count>
  - Added: `path/x.cs`, `path/y.sql`, ...
  - Modified: `path/z.cs`, ...
- Public surface added:
  - Endpoints: `POST /api/employees`, `GET /api/employees/{id}`
  - Handlers: `CreateEmployeeCommandHandler`, `GetEmployeeByIdQueryHandler`
  - Migrations: `20260423_AddEmployeeTable.sql`
- Tests: <unit passed>/<unit total>, <integration passed>/<integration total>
- Follow-ups (if any): <short bullets, or "none">
- Ready for: `/speckit.analyze`, PR to `main`
```

Gather the data with plain shell/git commands before composing the comment:
- `git rev-parse --abbrev-ref HEAD` → branch
- `git log --oneline <merge-base>..HEAD` → commits since feature branch diverged
- `git diff --name-status <merge-base>..HEAD` → files added/modified/deleted
- Cross-reference with tasks.md and plan.md to label public surface accurately

### § D — Optional config

Read `.specify/trello-sync.json` if present. Recognized keys (all optional):

```json
{
  "enabled": true,
  "auto_create_checklist_items": false,
  "mid_task_checkpoints": true,
  "comment_style": "bullets",
  "redact_paths_matching": ["secrets/", ".env"]
}
```

- `enabled: false` → skip Trello sync entirely for this run, regardless of card resolution.
- `auto_create_checklist_items` defaults to `false` — do not silently create checklist items on the card unless explicitly enabled.
- `mid_task_checkpoints` defaults to `true`. Set to `false` to only comment at task completion.
- `redact_paths_matching` — substrings; any file path containing one of these is replaced with `<redacted>` in comments.

### § E — Failure handling

- Any Trello MCP call failure → log a single warning line, continue implementation. Never halt the implementation loop because of Trello sync issues.
- Do not retry more than once per call. Do not loop on transient failures.
- If >3 consecutive Trello calls fail in a single run, set Trello sync to **disabled** for the remainder of the run and surface a summary warning in the final user-facing report.
