# legal-frontdoor coding standards

Read at review, not while building. Each rule comes from human review threads on merged PRs; (n) is the number of threads. A broken rule in a section marked **blocker** blocks the push. Every other broken rule is a non-blocker.

## 1. Names

- Use the product's term, not a synonym: `applicability`, not `description`. (3)
- No short forms (`sent`). Use the codebase's name for the role (`patch`). An error class says what failed (`ToolRuntimeMisconfigurationError`). (4)
- A name is true: `XError.toCompletion` is not used for a different error, and a log line says what happened. (2)
- A file suffix has one meaning. `.skill.ts` is for agent skills only. (1)

## 2. Where code goes

- A helper not specific to one feature goes in `utils/`. (3)
- A folder name is a contract: model calls are in `llm/`, and only they. (2)
- A service does not know its caller. `conversation` does not know about agent steps. `ToolService` knows only `ToolError` and `AgentFeedback`, and each tool owns its own errors. The agent loop does not import from one tool. (8)
- A limit, type or schema lives in the layer that owns it. (4)
- Clients and services come from the DI container, not `new` in a handler. (3)

## 3. Reuse before new code

- Before a new method, name the existing one and why it does not fit (`hasPermission('VIEW_DASHBOARD')`, `getOriginalDocOrNull`). (7)
- The same block in two channels (Slack, email) becomes one helper. (2)
- Prefer the platform or a maintained library to our own code (`Intl.Segmenter` for sentences). (3)
- Add to an existing model call before adding a new call. (3)

## 4. Scope

- Build only the current phase. No option, parameter, column or export that nothing uses today. (8)
- Inline a helper or constant that has one caller. (4)
- No file in the PR that the change does not need (ADRs, scratch tests). (2)
- A new tool is behind a feature flag, and the gate has a test. (2)

## 5. Types

- No `as` assertion. Narrow, or parse. (4)
- Data from outside the process is parsed with a zod schema. (4)
- Make the wrong state impossible: a union with a `code`, a type derived from the enum, an existing enum reused. (4)
- Handle `undefined` where an index or a lookup can miss. (3)

## 6. Errors

- A service throws its own typed errors. The caller uses `instanceof`, never the message text or the status code. (6)
- Separate "try again" from "will fail again". Use the `AgentFeedback` error for what the model can correct, and throw what it cannot. (7)
- Keep partial success: one failed item does not discard the others. (4)
- Log the error where it is caught. (1)

## 7. Database

- Use zapatos types through SQL interpolation, and derive with `Pick`. (2)
- One query where one is sufficient (upsert, `findAll`). (3)
- A paged list has an order that does not move between pages. (2)
- A text column is NOT NULL with an empty default, and each column has a use. (3)

## 8. Calls to external services (blocker)

- Timeout: state it as a total, including SDK retries, and show it holds past Node's 300 s header timeout. (3)
- Memory: check the size before a download, stream or cap it, and state the headroom when calls run in parallel. (4)
- A tool that can run longer than a queue lease says how a second run is prevented. (2)
- Cleanup does not delay a result that is ready. (1)
- Set a security default explicitly, and assert its value in the test. (1)
- Do constant work once per process, not on each call. (3)

## 9. Model calls and model output

- Try the simple call first (whole input, higher effort) before chunks. (2)
- Set truncation, cap output field lengths, and log when either cuts. (2)
- The text logic works for languages other than English. (2)
- Send a shared prefix so later calls can use the prompt cache. (1)
- A `completed` status is not proof: check each step. Validate a model-written file before we serve it. (3)
- Prompt text describes the task. It does not name tools. (2)

## 10. Interfaces and style

- Do not expose an implementation detail (sentence ids, raw SDK resources). Return what the caller needs. (4)
- No hidden side effect, and no hand copy of another tool's shape. (2)
- Prefer `map`/`reduce` to `push` in a loop, and no nested inline functions. (3)

## 11. Proof

- The PR body and the tool description say what the code does. (2)
- A build or package change includes how it was verified. (1)
- In a stack, a change goes in the PR whose title covers it. (2)
