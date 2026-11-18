# legal-frontdoor coding standards

These rules apply to `legal-frontdoor/`, in addition to `CODING_STANDARDS.md`. (n) is the number of human review threads behind a rule. A broken rule in a section marked **blocker** blocks the push. Every other broken rule is a non-blocker.

## 1. Where code goes

- Model calls are in `llm/`, and only they. (2)
- `conversation` does not know about agent steps. `ToolService` knows only `ToolError` and `AgentFeedback`, and each tool owns its own errors. The agent loop does not import from one tool. (8)
- Clients and services come from the DI container, not `new` in a handler. (3)

## 2. Tools and errors

- A new tool is behind a feature flag, and the gate has a test. (2)
- Use the `AgentFeedback` error for what the model can correct, and throw what it cannot. (7)
- A tool description says what the tool does. (2)

## 3. Database

- Use zapatos types through SQL interpolation, and derive with `Pick`. (2)
- One query where one is sufficient (upsert, `findAll`). (3)
- A paged list has an order that does not move between pages. (2)
- A text column is NOT NULL with an empty default, and each column has a use. (3)

## 4. Calls to external services (blocker)

- Timeout: state it as a total, including SDK retries, and show it holds past Node's 300 s header timeout. (3)
- Memory: check the size before a download, stream or cap it, and state the headroom when calls run in parallel. (4)
- A tool that can run longer than a queue lease says how a second run is prevented. (2)
- Cleanup does not delay a result that is ready. (1)
- Set a security default explicitly, and assert its value in the test. (1)
- Do constant work once per process, not on each call. (3)

## 5. Model calls and model output

- Add to an existing model call before adding a new call. (3)
- Try the simple call first (whole input, higher effort) before chunks. (2)
- Set truncation, cap output field lengths, and log when either cuts. (2)
- The text logic works for languages other than English. (2)
- Send a shared prefix so later calls can use the prompt cache. (1)
- A `completed` status is not proof: check each step. Validate a model-written file before we serve it. (3)
- Prompt text describes the task. It does not name tools. (2)
