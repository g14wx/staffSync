# GEMINI.md

## Commit Rules

Source: `task.md`.

### Commit Message Format

```text
<type>(<PROJECTCODE>-<task-number>): <short description>
```

Scope must always be project code + Trello task number/ID.

### Correct Examples

```text
chore(STAFF-0001): create n-tier backend solution
feat(STAFF-0002): add employee domain model
feat(STAFF-0003): add employee cqrs commands
feat(STAFF-0004): add employee cqrs queries
feat(STAFF-0005): add dapper employee repository
feat(STAFF-0006): add employee CRUD endpoints
fix(STAFF-0007): enforce phone number validation
```

### Incorrect Examples

```text
feat(api): add employee CRUD endpoints
feat(employee): add employee domain model
chore(solution): create solution
```

### Branch Naming

```text
<version>/<type>/<PROJECTCODE>-<task-number>-<kebab-case-description>
```

Example:

```text
v1/feat/STAFF-0003-create-employee-cqrs-commands
```

### Tagging Rules

Supported tag families:

```text
pre-release/vX.Y.Z
release/vX.Y.Z
release-qa/vX.Y.Z
```

Rules:

* Annotated tags for releases.
* Fetch tags before picking next version.
* Never move release tags unless told.
* Never delete remote tags unless told.
* Do not push tags automatically unless task is release/tagging.

### Trello Source Of Truth

When Trello MCP available, pull from Trello card:

* Version.
* Task number / task ID.
* Project code name.
* Work type.

Never invent Trello info. If missing and blocks safe naming, ask.
