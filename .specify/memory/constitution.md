# Employee Records Backend Constitution

## Core Principles

### I. Backend-Only Scope

This project is a backend-only technical-test submission for managing employee records. All specs, tasks, implementation plans, and code changes must stay focused on backend work unless the user explicitly expands the scope.

The default scope includes ASP.NET Core Web API, .NET 10 LTS, SQL Server, Transact-SQL, Dapper or ADO.NET, N-Tier architecture, CQRS, validation, API error handling, backend tests, backend documentation, and optional Docker for API + SQL Server.

The default scope excludes React, Next.js, Vite, frontend folders, UI components, CSS, frontend validation, frontend routing, frontend Dockerfiles, and frontend documentation.

### II. N-Tier + CQRS Architecture

Every backend feature must preserve real N-Tier separation and mandatory CQRS.

The expected backend structure is:

```text
EmployeeRecords.sln
└── backend/
    ├── Domain/
    ├── Application/
    ├── Infrastructure/
    └── WEB.API/
```

Layer rules:

* `Domain` contains pure domain concepts only.
* `Application` contains CQRS commands, queries, handlers, validators, DTOs, repository interfaces, and use-case contracts.
* `Infrastructure` contains Dapper or ADO.NET implementations, SQL connection factories, SQL query definitions, and database access.
* `WEB.API` contains controllers or FastEndpoints, request/response mapping, Swagger/OpenAPI, error handling middleware, and API composition.

CQRS is non-negotiable:

* Commands mutate state.
* Queries read state.
* Controllers must remain thin.
* Controllers must not call Dapper, ADO.NET, or repositories directly.
* Repository interfaces live in `Application`.
* Repository implementations live in `Infrastructure`.
* SQL details must never leak into `Application` or `WEB.API`.

Required CQRS operations for the employee module:

```text
CreateEmployeeCommand
UpdateEmployeeCommand
DeleteEmployeeCommand
GetEmployeeByIdQuery
GetEmployeesQuery
```

### III. SQL Server Direct Persistence

The project must use SQL Server with Transact-SQL and direct persistence through Dapper or ADO.NET.

Dapper is preferred unless a task explicitly chooses ADO.NET and documents why.

Entity Framework Core must not be used for persistence in this project.

All SQL access must obey these rules:

* Use parameterized queries.
* Never concatenate user-provided values into SQL.
* Keep SQL implementation inside `Infrastructure`.
* Use `Microsoft.Data.SqlClient` for SQL Server connectivity.
* Use async database methods where possible.
* Whitelist sortable columns before using them in SQL.
* Use SQL Server `DATE` for `HireDate` and format only at API boundaries.

The database script must exist at:

```text
/database/create-employees-table.sql
```

The script must create the `Employees` table, required constraints, primary key, and an index for `HireDate` sorting.

### IV. Validation, Errors, And API Contracts

Backend validation is mandatory, enforced by FluentValidation in the `Application` layer, and executed by the ASP.NET Core pipeline before any handler runs. See Principle VI for validator code discipline.

The API must support the employee model:

```text
EmployeeID
EmployeeLastName
EmployeeFirstName
EmployeePhone
EmployeeZip
HireDate
```

Request-contract validation rules (enforced by `Application` validators):

* `EmployeeFirstName` is required, trimmed, non-whitespace, max length 100.
* `EmployeeLastName` is required, trimmed, non-whitespace, max length 100.
* `EmployeePhone` is required and must match the exact regex `^\([0-9]{3}\) [0-9]{3}-[0-9]{4}$`. Inputs are rejected, not normalised.
* `EmployeeZip` is required and must match `^\d{5}(-\d{4})?$` unless a task explicitly overrides the ZIP format.
* `HireDate` is required. The API accepts and returns `MM/DD/YYYY`. Validators must reject unparseable values, future dates beyond a documented business horizon, and dates before a documented epoch (e.g. `1900-01-01`). Date comparisons must go through the project's business-timezone helper — never through `DateTime.Now` or raw `DateTime.UtcNow`.
* On update, `EmployeeID` in the route must match the body (when present) or the body's ID field must be absent; mismatches are 400, not silently overridden.
* Unknown/extra JSON fields must not cause silent data loss — either reject with 400 or ignore explicitly per a documented policy.
* Pagination inputs (`page`, `pageSize`) must be bounded (`page >= 1`, `1 <= pageSize <= 100`) at the validator level.
* `sortBy` must be validated against a whitelist identical to the SQL-side whitelist (see Principle III).

The API must expose these endpoints:

```http
GET    /api/employees
GET    /api/employees/{employeeId}
POST   /api/employees
PUT    /api/employees/{employeeId}
DELETE /api/employees/{employeeId}
```

`GET /api/employees` must support sorting by `HireDate` and should support pagination/filtering when practical.

Error handling rules:

* Validation errors return HTTP 400 with field-level details.
* Missing records return HTTP 404.
* Unexpected errors return HTTP 500 with safe messages.
* Do not leak stack traces, SQL internals, connection strings, or sensitive implementation details.

### V. Testable, Review-Ready Delivery

Every change must be reviewable, testable, and explainable.

Before a task is considered complete, it must include:

* Clear acceptance criteria.
* Build verification.
* Test verification when tests exist.
* Manual API verification when automated tests are not available.
* Documentation updates when behavior, setup, or endpoints change.
* A summary of changed files and why they changed.

Expected validation commands:

```bash
dotnet build EmployeeRecords.sln
dotnet test EmployeeRecords.sln
```

If tests do not exist yet, the spec must explain the manual validation steps and whether tests should be added as part of the task.

### VI. Validator Discipline (FluentValidation)

Every command and query that accepts user input must have a dedicated `FluentValidation.AbstractValidator<T>` in the `Application` layer. Validators are the single source of contract enforcement — handlers must assume their inputs are already valid.

These patterns are derived from the reference validator `CreateCargoDayCommandValidator` (stocktaking codebase) and are mandatory here:

1. **One validator per command/query.** File named `<CommandName>Validator.cs`, co-located with the command under `Application/Employees/Commands/<Op>/` or `Application/Employees/Queries/<Op>/`.

2. **Validator owns the full request contract.** Required fields, lengths, regex formats, bounds, enum membership, sort-field whitelist membership, and collection non-emptiness all live in the validator — never in the handler, never in the controller.

3. **Repository-backed checks use async validators.** When a rule needs I/O (existence, uniqueness, referential integrity — e.g. "employee with this ID exists", "phone number not already taken"), inject the repository interface into the validator's constructor and wire it with `SetAsyncValidator(new <DedicatedRuleValidator>(repo, ...))`. Do not inline `MustAsync` lambdas for rules that are reusable across commands.

4. **Cross-command rules are reusable generics.** Shared checks (e.g. "these IDs exist and are active") must be implemented as a generic async validator (e.g. `ValidateEmployeeIdsExist<TCommand>`) so the same rule can be attached to create, update, and batch commands without duplication. Place them in `Application/Employees/CommonCustomValidators/`.

5. **Conditional rules use `.When(...)` / `.Unless(...)`.** Context-dependent requirements (e.g. "admin must select a company when not scoped by tenant") must be expressed declaratively, never via `if` branches inside a single `Must` lambda. Example:

   ```csharp
   RuleFor(x => x.BelongsToCompanyId)
       .Must(x => x is > 0)
       .WithMessage("You are an admin, you must select from which company this item belongs to")
       .When(x => x.LoggedUserBelongsToCompanyId == null);
   ```

6. **Nullable-aware predicates.** Distinguish "absent" from "invalid". Prefer `x is null or > 0` over `x > 0`, and guard length / format rules with `.When(x.Field is not null)`:

   ```csharp
   RuleFor(x => x.Comments)
       .MaximumLength(500)
       .When(x => x.Comments is not null)
       .WithMessage("Comments cannot exceed 500 characters");
   ```

7. **Non-trivial predicates are named static methods.** Rules that need more than a one-line lambda must live as `private static bool <RuleName>(...)` on the validator. Example pattern — `Must(BeValidFutureDate)`:

   ```csharp
   private static bool BeValidFutureDate(DateTime scheduledDate)
   {
       var tz = TimeZoneInfo.FindSystemTimeZoneById("America/New_York");
       var now = TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow, tz);
       return scheduledDate >= now.Date;
   }
   ```

8. **Error messages are human-readable and actionable.** `.WithMessage(...)` must state the rule and, where useful, the fix. Reject default messages like `'Field' must not be empty.` for any field a caller controls.

9. **Timezone-sensitive validation goes through a single helper.** Date-comparison rules must resolve the business timezone centrally. Never compare against `DateTime.Now`. UTC comparisons are allowed only when the value is explicitly a UTC timestamp.

10. **Collection rules enforce presence and size together.** For required non-empty collections use `Must(x => x?.Count > 0)` rather than `.NotEmpty()` alone on a nullable collection:

    ```csharp
    RuleFor(x => x.InvoiceIds)
        .Must(x => x?.Count > 0)
        .WithMessage("There must be at least one invoice in a cargo day");
    ```

11. **Validators are DI-registered and pipeline-invoked.** Register via `FluentValidation.DependencyInjectionExtensions`. Controllers and handlers must **not** call `validator.Validate(...)` manually; validation runs in the request pipeline, emits HTTP 400 with field-level detail, and short-circuits before the handler.

12. **Handlers return `ErrorOr<T>`.** Handler outputs use `ErrorOr` so domain and repository errors surface as typed `Error` values. Controllers map `Errors.Validation` → 400, `Errors.NotFound` → 404, `Errors.Conflict` → 409, `Errors.Unexpected` → 500. Handlers must not throw for expected business errors.

13. **Validator tests are mandatory.** For every non-trivial rule, provide at minimum one passing case and one failing case using `TestValidate`, `ShouldHaveValidationErrorFor`, and `ShouldNotHaveValidationErrorFor`. Async rules that hit repositories must use mocked repositories — not the real database.

14. **Reference shape.** A compliant validator looks like this:

    ```csharp
    public class CreateEmployeeCommandValidator : AbstractValidator<CreateEmployeeCommand>
    {
        public CreateEmployeeCommandValidator(IEmployeeRepository employees)
        {
            RuleFor(x => x.EmployeeFirstName)
                .NotEmpty().WithMessage("First name is required")
                .MaximumLength(100).WithMessage("First name cannot exceed 100 characters");

            RuleFor(x => x.EmployeePhone)
                .NotEmpty().WithMessage("Phone is required")
                .Matches(@"^\([0-9]{3}\) [0-9]{3}-[0-9]{4}$")
                .WithMessage("Phone must be formatted as (XXX) XXX-XXXX");

            RuleFor(x => x.HireDate)
                .NotEmpty().WithMessage("Hire date is required")
                .Must(BeWithinBusinessRange)
                .WithMessage("Hire date must be between 1900-01-01 and today");

            RuleFor(x => x.EmployeePhone)
                .SetAsyncValidator(new ValidateEmployeePhoneUnique<CreateEmployeeCommand>(employees));
        }

        private static bool BeWithinBusinessRange(DateTime hireDate) =>
            hireDate >= new DateTime(1900, 1, 1) && hireDate <= DateTime.UtcNow.Date;
    }
    ```

Domain-level invariants (e.g. canonical phone value object, ZIP parsing) remain the responsibility of the `Domain` layer. Validators enforce the request contract; domain types enforce the invariant once the contract is met. The two layers must not redundantly re-validate the same rule.

### VII. MediatR Pipeline Behaviors

Cross-cutting concerns that apply to every command/query must be implemented as MediatR `IPipelineBehavior<TRequest, TResponse>` — never duplicated inside handlers, and never inlined into controllers.

Mandatory behaviors, registered in this order (outermost first):

1. **LoggingBehavior** — start/stop log with correlation ID, request type name, elapsed milliseconds, and outcome (success, validation failure, not-found, unexpected). Must not log request bodies by default; see Principle IX for redaction rules when bodies are logged.
2. **ValidationBehavior** — resolves all registered `IValidator<TRequest>` instances, aggregates failures, and short-circuits with `ErrorOr<T>.Errors` (validation errors). Handlers never run if validation fails. This behavior is the *only* place validators are invoked programmatically; controllers, endpoints, and handlers must not call `Validate(...)` directly.
3. **UnhandledExceptionBehavior** — catches exceptions thrown out of handlers, logs them with full context, and returns `Error.Unexpected(...)` via `ErrorOr`. Stack traces and SQL details must not leak into the API response (Principle IV).
4. **TransactionBehavior** (commands only) — opens a single `IDbConnection` + transaction for the handler, commits on `ErrorOr.IsError == false`, rolls back otherwise. Queries must not participate in this behavior. Detection is by marker interface (e.g. `ICommand<T>`) — reflection on naming conventions is not acceptable.

Additional rules:

* Behaviors live in `Application/Common/Behaviors/`.
* Behaviors must be pure cross-cutting infrastructure — no domain logic, no repository calls beyond what the concern requires (e.g. `TransactionBehavior` uses `IDbConnectionFactory`).
* New cross-cutting concerns (caching, authorization, audit) must be added as additional behaviors, not as handler decorators or controller filters.
* Behaviors must be covered by at least one integration test per behavior verifying the short-circuit / commit / rollback path.

### VIII. Idempotency For State-Changing Operations

`POST /api/employees` (and any future `POST` that creates a resource) must be idempotent-safe so that network retries cannot create duplicate rows.

Required mechanism:

* The client supplies an `Idempotency-Key` header — an opaque string up to 128 chars, case-sensitive.
* The server stores `(idempotency_key, request_hash, response_status, response_body_hash, created_at_utc)` in an `IdempotencyKeys` SQL Server table with `PRIMARY KEY (idempotency_key)`.
* On first request: the handler runs, persists the employee, and records the idempotency entry inside the same transaction (Principle VII).
* On replay with the same key and the same body hash: return the original `201 Created` response and `Location` header without re-running the handler.
* On replay with the same key but a different body hash: return `HTTP 409 Conflict` with a typed `Errors.Conflict` error — never silently accept divergent bodies.
* Entries older than a documented retention window (default 24 hours) may be pruned by a scheduled job; retention must be documented in the README.

Validator responsibility:

* `Idempotency-Key` format (length, character set) is validated at the request-contract level via a dedicated `IdempotencyKeyAttribute` or a binding-time validator — it is part of the request contract, not a handler concern.

Opt-out:

* For the technical-test scope this mechanism is mandatory for `POST /api/employees`. `PUT` and `DELETE` are idempotent by construction and do not require the header.
* If a future task explicitly removes idempotency support, it must document the incident/retry story it replaces it with.

### IX. Structured Logging And PII Protection

Logs are a privileged surface — they are searched, retained, and often replicated. The employee model contains PII; logging must treat it accordingly.

Required logging discipline:

* Logs must be structured (key/value), not interpolated strings. Use the logging abstraction's property syntax (`_logger.LogInformation("Created employee {EmployeeId}", id)`), never `$"...{id}..."`.
* Every log entry emitted from a request-scoped pipeline must carry a `CorrelationId` property, generated at the request edge and propagated through MediatR pipeline behaviors and repository calls.
* Log levels:
  * `Debug` — developer-only detail; off in production.
  * `Information` — lifecycle events (request received, handler succeeded, entity persisted).
  * `Warning` — recovered validation / not-found outcomes.
  * `Error` — unhandled exceptions or unexpected errors surfaced via `Errors.Unexpected`.
  * `Critical` — infrastructure failure (DB unreachable, connection pool exhausted).

PII redaction rules (non-negotiable):

* `EmployeePhone`, `EmployeeZip`, full name combinations, and any raw request body **must not** be logged at `Information` level or above.
* When diagnostic logging of these fields is unavoidable (e.g. Debug during local triage), they must pass through a central redactor:
  * Phone: `(XXX) XXX-XXXX` → `(***) ***-XXXX` (keep the last 4 digits only).
  * ZIP: `12345-6789` → `12345-****`.
  * Names: log only the first character of each name part (`"J*** D***"`).
  * Employee IDs (`Guid`) are not PII and may be logged in full.
* Redaction is implemented as a single helper or formatter in `Infrastructure/Logging/` and wired through the logging pipeline — not duplicated at each call site.
* Error responses to clients must never include PII echoed back from the request.

Observability:

* Each of the four MediatR behaviors (Principle VII) must emit a structured log event with the same correlation ID so a single request can be traced end-to-end.
* Failed SQL operations must log the parameterised statement (template only — never the parameter values for PII columns) and the SQL error code.

### X. .NET And C# Clean Code (Non-Negotiable)

Clean code and .NET/C# best practices are mandatory under all circumstances. The `dotnet-standards-enforcer` Tessl tile is the preferred enforcement channel, but the rules below are binding whether or not the tile is available. Tile-unavailable is *not* a waiver.

#### Compiler And Analyzer Strictness

Every project in the solution must set:

```xml
<PropertyGroup>
  <TargetFramework>net10.0</TargetFramework>
  <Nullable>enable</Nullable>
  <ImplicitUsings>enable</ImplicitUsings>
  <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
  <AnalysisLevel>latest-recommended</AnalysisLevel>
  <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
  <LangVersion>latest</LangVersion>
</PropertyGroup>
```

Required analyzers (or equivalent — document substitutions in the PR):

* `Microsoft.CodeAnalysis.NetAnalyzers` (bundled with the SDK; must not be disabled).
* `Roslynator.Analyzers`.
* `SonarAnalyzer.CSharp`.
* `StyleCop.Analyzers` (with project-owned `stylecop.json`).

Analyzer suppressions are allowed only with a same-line or adjacent `// justification: <reason>` comment. Blanket `<NoWarn>` entries in `.csproj` or `.editorconfig` are not allowed for analyzer IDs — use per-file or per-line suppression.

#### Async Discipline

* Every I/O-bound method is `async Task` / `async Task<T>`; CPU-bound work stays synchronous.
* Every public `async` method accepts a `CancellationToken cancellationToken` as its last parameter and propagates it to every awaited call.
* `ConfigureAwait(false)` is required in `Application` and `Infrastructure` layers; optional in `WEB.API`.
* `async void` is forbidden except for framework event handlers.
* `.Result`, `.Wait()`, `.GetAwaiter().GetResult()` are forbidden in application code.
* Async methods end in `Async` (`GetEmployeesAsync`, `CreateEmployeeAsync`).

#### Nullable Reference Types

* `#nullable disable` is forbidden anywhere in the solution.
* The null-forgiving operator `!` is forbidden without a `// justification:` comment.
* Public API signatures must expose nullable annotations accurately — no `string` where `string?` is correct.
* Nullable warnings (`CS86xx`) are errors (inherited from `TreatWarningsAsErrors`) — do not suppress them globally.

#### Types And Visibility

* `sealed` by default for any class not explicitly designed for inheritance.
* `record` (or `record struct`) for immutable DTOs, commands, queries, and event contracts.
* `readonly struct` for value objects (Domain layer).
* Default visibility is `internal`; `public` is used only at published assembly boundaries.
* One public type per file; file name matches the type name; folder structure matches the namespace.

#### Dependency Injection

* Constructor injection only. No service locator, no `IServiceProvider.GetService<T>()` outside the composition root.
* Every registration in `Program.cs` / extension methods states its lifetime explicitly (`AddSingleton`, `AddScoped`, `AddTransient`) — no implicit defaults.
* No captive dependencies: a `Singleton` must not depend on a `Scoped` or `Transient` service.
* Open generics (behaviors, validators) are registered via scan-and-register (`Scrutor` or equivalent) — never hand-rolled registration lists for them.

#### Configuration

* Strongly-typed `IOptions<T>` / `IOptionsSnapshot<T>` / `IOptionsMonitor<T>` for every configuration section.
* Raw `IConfiguration["..."]` reads are allowed only in the composition root (`Program.cs` / DI extension methods).
* Options classes are validated at startup via `.ValidateDataAnnotations().ValidateOnStart()`.
* Secrets (connection strings, API keys) never live in source control — use user-secrets in development, environment variables or a secret store in higher environments.

#### Naming Conventions

* Microsoft / StyleCop naming:
  * `PascalCase` — types, public members, constants.
  * `camelCase` — parameters, locals.
  * `_camelCase` — private instance fields.
  * `s_camelCase` — private static fields.
  * Interfaces start with `I`; generic type parameters start with `T`.
* No Hungarian notation. No underscore prefixes on publics.
* Abbreviations follow the BCL convention (`Id`, not `ID`; `Url`, not `URL`).

#### Error Handling

* `catch (Exception)` is allowed only at a documented top-level boundary (e.g. `UnhandledExceptionBehavior` — Principle VII). Everywhere else, catch specific exception types.
* Expected business errors flow as `ErrorOr<T>` values (Principle VI.12) — do not throw for them.
* Swallowed exceptions are forbidden: every `catch` either rethrows, maps to `ErrorOr`, or logs at `Error`/`Critical` with full context.
* `throw ex;` (rethrow that destroys the stack trace) is forbidden — use `throw;`.

#### Code Hygiene

* `dynamic` is forbidden in application code.
* Reflection in hot paths (per-request) is forbidden without a justification comment and a benchmark.
* JSON attributes (`System.Text.Json`, `Newtonsoft.Json`) live on DTOs only — never on Domain entities or value objects.
* No commented-out code in commits; either delete or keep with a tracking comment and an issue link.
* No magic numbers in business logic — extract named constants.
* Dead code (unused types, methods, parameters) is deleted, not preserved.

#### Formatting

* A root `.editorconfig` is committed to the repository.
* `dotnet format --verify-no-changes` must pass in CI. Formatting violations are a build break, not a review comment.
* Line endings, indentation (4 spaces for C#, 2 for JSON/YAML), and trimmed trailing whitespace are enforced through `.editorconfig`.

#### Tests

* Test projects inherit the same analyzer rule set as production projects; warnings are errors in tests too.
* Layout: Arrange / Act / Assert, one behavior per test, descriptive test names (`MethodName_Scenario_ExpectedOutcome`).
* `Thread.Sleep`, real wall-clock waits, and real network I/O are forbidden — use `FakeTimeProvider`, `TestServer`, in-memory fakes, or mocked repositories.
* Test isolation: no shared mutable state between tests; each test owns its setup and teardown.

#### Enforcement

If any item above cannot be satisfied (e.g. a third-party library forces a relaxation), the exception must be:

1. Scoped to the narrowest possible surface (one file or one method).
2. Justified inline with a `// justification:` comment citing the reason.
3. Called out explicitly in the PR description and in the relevant spec's "Risks And Assumptions" section.

## Backend Technical Constraints

The backend must target:

```text
.NET 10 LTS
net10.0
ASP.NET Core Web API
SQL Server
Transact-SQL
Dapper or ADO.NET
```

Recommended packages:

```text
Application:
- FluentValidation
- MediatR
- ErrorOr

Infrastructure:
- Dapper
- Microsoft.Data.SqlClient

WEB.API:
- FluentValidation.DependencyInjectionExtensions
- Swashbuckle.AspNetCore
```

Package rules:

* Use stable .NET 10-compatible packages.
* Avoid prerelease packages unless explicitly approved.
* Do not add Entity Framework Core for persistence.
* Do not add frontend packages.
* Do not add unnecessary dependencies.
* Document why a package is needed when adding it.

## Development Workflow

### Context-Aware Execution

This constitution is not a blind checklist. It is the governing rulebook for Spec-Kit and Claude Code.

Every spec and implementation must be context-aware:

* Read the repository state before acting.
* Use Trello MCP data when available.
* Use the current branch, tags, task type, and acceptance criteria to decide the correct workflow.
* Treat commands as required patterns, not as commands to run blindly when invalid for the environment.
* Document unavailable tools and continue with the closest safe equivalent.
* Do not invent task numbers, project codes, release versions, or Trello card details.
* Ask only when missing information blocks safe progress.
* Prefer small, traceable, reviewable changes.

### Spec-Kit Rules

When `/speckit.specify` is used, generated specs must:

1. Stay backend-only by default.
2. Preserve .NET 10 LTS.
3. Preserve N-Tier architecture.
4. Preserve CQRS.
5. Preserve Dapper or ADO.NET persistence.
6. Avoid Entity Framework Core persistence.
7. Include validation requirements.
8. Include API error handling requirements.
9. Include SQL Server and Transact-SQL requirements.
10. Include build/test/manual validation steps.
11. Include Trello-aware branch and commit context when relevant.
12. Include Tessl tile requirements when backend code is involved.
13. Include clear acceptance criteria.
14. Include risks and assumptions.
15. Avoid frontend tasks unless explicitly requested.

### Tessl Rules

The `dotnet-standards-enforcer` Tessl tile is mandatory for backend/.NET work.

Expected command when available:

```bash
tessl install dotnet-standards-enforcer
```

If the tile is local:

```bash
tessl install file:<path-to-dotnet-standards-enforcer-tile>
```

If local tiles exist, validate them with:

```bash
tessl tile lint ./tiles/dotnet-standards-enforcer
tessl tile pack --output ./dist ./tiles/dotnet-standards-enforcer
```

If Tessl is unavailable, the task must document the limitation and continue using this constitution, `CLAUDE.md`, and `TASK.md` as the rule source.

### Branch Naming

Every task branch must follow:

```text
<version>/<type>/<PROJECTCODE>-<task-number>-<kebab-case-description>
```

Example:

```text
v1/feat/STAFF-0003-create-employee-cqrs-commands
```

### Commit Style

Commits must follow:

```text
<type>(<PROJECTCODE>-<task-number>): <short description>
```

Correct examples:

```text
chore(STAFF-0001): create n-tier backend solution
feat(STAFF-0002): add employee domain model
feat(STAFF-0003): add employee cqrs commands
feat(STAFF-0004): add employee cqrs queries
feat(STAFF-0005): add dapper employee repository
feat(STAFF-0006): add employee CRUD endpoints
fix(STAFF-0007): enforce phone number validation
```

Incorrect examples:

```text
feat(api): add employee CRUD endpoints
feat(employee): add employee domain model
chore(solution): create solution
```

The commit scope must always be the project code plus Trello task number or task ID.

### Tagging

Supported tag families:

```text
pre-release/vX.Y.Z
release/vX.Y.Z
release-qa/vX.Y.Z
```

Rules:

* Prefer annotated tags.
* Fetch tags before deciding the next version.
* Never move release tags unless explicitly instructed.
* Never delete remote tags unless explicitly instructed.
* Do not push tags automatically unless the task explicitly requires release/tagging work.

## Quality Gates

A backend task is not complete until these checks are satisfied or explicitly documented as unavailable:

* The solution builds.
* Tests pass when tests exist.
* API behavior is manually verified when relevant.
* Validation behavior is verified — every command and query has a FluentValidation `AbstractValidator<T>` covering every input field, with passing and failing test cases for each non-trivial rule.
* Async / repository-backed rules use dedicated reusable validator classes wired via `SetAsyncValidator`, not inline `MustAsync` lambdas.
* Error behavior is verified — handlers return `ErrorOr<T>`, controllers map typed errors to the correct HTTP status, and no validation is performed manually inside handlers or controllers.
* All required MediatR pipeline behaviors (Logging, Validation, UnhandledException, Transaction) are registered in the correct order and exercised by at least one integration test each.
* `POST /api/employees` honours `Idempotency-Key` per Principle VIII — replays with the same body return the original response; divergent bodies return HTTP 409.
* Logs are structured, carry a `CorrelationId`, and never emit raw PII (phone, ZIP, full names, request bodies) at `Information` or above; PII redaction flows through the central redactor.
* The solution builds with `TreatWarningsAsErrors=true`, `Nullable=enable`, all required analyzers active, and `dotnet format --verify-no-changes` passing — no new warnings introduced, no analyzer suppressions without inline `// justification:` comments.
* Async methods accept and propagate `CancellationToken`; `async void`, `.Result`, and `.Wait()` are absent from application code.
* DI registrations have explicit lifetimes and no captive dependencies; configuration reads outside the composition root use strongly-typed `IOptions<T>` bound and validated at startup.
* SQL safety is preserved.
* N-Tier boundaries are preserved.
* CQRS boundaries are preserved.
* README or docs are updated when needed.
* The branch follows the naming rule.
* The commit style follows the required scope rule.
* The `dotnet-standards-enforcer` tile was loaded or the fallback was documented.

## Governance

This constitution supersedes informal project habits and must be treated as the governing source for Spec-Kit and Claude Code behavior in this repository.

All generated specs, implementation plans, PR summaries, and task completions must comply with this constitution.

Amendments are allowed only when the user explicitly changes project direction or adds new constraints.

When this constitution conflicts with a user request, the latest explicit user instruction wins, but the conflict must be documented.

When this constitution conflicts with `CLAUDE.md` or `TASK.md`, Claude must stop and document the inconsistency before proceeding, unless the user instruction clearly resolves the conflict.

All task specs must verify compliance with:

* Backend-only scope.
* .NET 10 LTS.
* N-Tier architecture.
* CQRS.
* Dapper or ADO.NET persistence.
* SQL Server and Transact-SQL.
* No EF Core persistence.
* Git/Trello workflow.
* Tessl tile usage.

**Version**: 1.3.0 | **Ratified**: 2026-04-23 | **Last Amended**: 2026-04-23

## Changelog

* **1.3.0** (2026-04-23):
  * Added Principle X: .NET And C# Clean Code (Non-Negotiable). Codifies compiler/analyzer strictness (`TreatWarningsAsErrors`, `Nullable=enable`, `NetAnalyzers` + `Roslynator` + `SonarAnalyzer` + `StyleCop`), async discipline (mandatory `CancellationToken`, no `async void` / `.Result`), nullable discipline, type/visibility defaults (`sealed`, `record`, `internal`-first), DI rules (explicit lifetimes, no service locator, no captive dependencies), strongly-typed configuration, naming conventions, error handling, code hygiene, `.editorconfig` + `dotnet format` enforcement, and test-project parity. Tile-unavailable is explicitly not a waiver.
  * Extended Quality Gates to verify clean-code compliance: analyzer-clean build, formatting, cancellation-token propagation, DI lifetime correctness, and `IOptions<T>`-based configuration.

* **1.2.0** (2026-04-23):
  * Added Principle VII: MediatR Pipeline Behaviors. Mandates `LoggingBehavior`, `ValidationBehavior`, `UnhandledExceptionBehavior`, and `TransactionBehavior` (commands only), with a fixed registration order. Removes manual `Validate(...)` calls from handlers/controllers.
  * Added Principle VIII: Idempotency For State-Changing Operations. Requires `Idempotency-Key` header on `POST /api/employees`, a persisted `IdempotencyKeys` table inside the handler's transaction, replay semantics, and HTTP 409 on divergent bodies.
  * Added Principle IX: Structured Logging And PII Protection. Mandates structured logs with `CorrelationId` propagation, level discipline, and a central redactor for phone / ZIP / name fields. Raw PII forbidden at `Information` or above.
  * Extended Quality Gates to verify behavior registration/coverage, idempotency replay semantics, and PII redaction.

* **1.1.0** (2026-04-23):
  * Tightened Principle IV validation rules: explicit regex, bounded pagination, trimmed strings, `sortBy` whitelist parity with SQL, `HireDate` epoch + business-timezone comparison, update-route ID parity, extra-field policy.
  * Added Principle VI: Validator Discipline (FluentValidation). Codifies 14 mandatory patterns derived from the reference `CreateCargoDayCommandValidator` (stocktaking codebase) — one validator per command, repo-injected async validators via `SetAsyncValidator`, reusable generic cross-command validators, `.When`/`.Unless` for conditional rules, named static predicates, `ErrorOr<T>` handler returns, and mandatory validator tests.
  * Extended Quality Gates to cover validator and error-mapping compliance.
