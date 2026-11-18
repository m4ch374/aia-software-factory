# Coding standards

These rules apply to every service. A service can have more rules in `<service>.md` in this folder, named after the service's top folder.

Read at review, not while building. Each rule comes from human review threads on merged PRs; (n) is the number of threads. A broken rule in a section marked **blocker** blocks the push. Every other broken rule is a non-blocker.

## 1. Names

- Use the product's term, not a synonym: `applicability`, not `description`. (3)
- No short forms (`sent`). Use the codebase's name for the role (`patch`). An error class says what failed (`ToolRuntimeMisconfigurationError`). (4)
- A name is true: `XError.toCompletion` is not used for a different error, and a log line says what happened. (2)
- A file suffix has one meaning. `.skill.ts` is for agent skills only. (1)

## 2. Where code goes

- A helper not specific to one feature goes in `utils/`. (3)
- A folder name is a contract: a folder holds only what its name says. (2)
- A service does not know its caller, and each module owns its own errors. (8)
- A limit, type or schema lives in the layer that owns it. (4)

## 3. Reuse before new code

- Before a new method, name the existing one and why it does not fit (`hasPermission('VIEW_DASHBOARD')`, `getOriginalDocOrNull`). (7)
- The same block in two channels (Slack, email) becomes one helper. (2)
- Prefer the platform or a maintained library to our own code (`Intl.Segmenter` for sentences). (3)

## 4. Scope

- Build only the current phase. No option, parameter, column or export that nothing uses today. (8)
- Inline a helper or constant that has one caller. (4)
- No file in the PR that the change does not need (ADRs, scratch tests). (2)

## 5. Types

- No `as` assertion. Narrow, or parse. (4)
- Data from outside the process is parsed with a zod schema. (4)
- Make the wrong state impossible: a union with a `code`, a type derived from the enum, an existing enum reused. (4)
- Handle `undefined` where an index or a lookup can miss. (3)

## 6. Errors

- A service throws its own typed errors. The caller uses `instanceof`, never the message text or the status code. (6)
- Separate "try again" from "will fail again". (7)
- Keep partial success: one failed item does not discard the others. (4)
- Log the error where it is caught. (1)

## 7. Interfaces and style

- Do not expose an implementation detail (sentence ids, raw SDK resources). Return what the caller needs. (4)
- No hidden side effect, and no hand copy of another module's shape. (2)
- Prefer `map`/`reduce` to `push` in a loop, and no nested inline functions. (3)

## 8. Proof

- The PR body and each description say what the code does. (2)
- A build or package change includes how it was verified. (1)
- In a stack, a change goes in the PR whose title covers it. (2)
