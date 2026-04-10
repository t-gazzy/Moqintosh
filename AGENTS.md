# AGENTS.md

## Language
- Respond concisely and politely in the language used by the user.

## Code Style
1. All comments must be written in English.
2. Write concise code and avoid redundancy.
3. Follow the conventions of existing code to maintain consistency.
4. **Naming**: File names, directory names, and class names must always be written in UpperCamelCase. Use terminology that follows the relevant specification, and choose names that accurately reflect the actual behavior or role.
5. **Strict SwiftLint Compliance**: Follow rules in `.swiftlint.yml`. No warnings/errors allowed.
6. **Explicit Type Annotations**:
   - Always provide explicit type annotations for public/internal properties and constants.
   - For local variables, use type annotations if the assigned value's type is not immediately obvious.
   - *Example*: `let count: Int = 10` or `let user: User = .init()`.
7. **Initialization**:
   - Favor `.init()` syntax when the type is explicitly declared.
   - Perform all property initializations within the `init` method to support Dependency Injection. Avoid inline default values for complex types.
8. **Safety & Modernity**:
   - Use `async/await` for asynchronous code.
   - Force unwrapping (`!`) is allowed only when a `nil` value is a programming error (i.e., it should never happen at runtime). In all other cases, use `guard let` or `if let`.
   - To enforce API call ordering (e.g., `initialize()` must be called before `doSomething()`), use `precondition` or `preconditionFailure` with a descriptive message instead of `!`.
9. **Annotations**:
   - Apply necessary attributes like `@escaping`, `@discardableResult`, `@MainActor`, and `@Observable` appropriately.

## Access Control
Apply the narrowest modifier that satisfies the requirement.

| Modifier | Scope |
|---|---|
| `open` | Subclassable/overridable from another module |
| `public` | Accessible from another module |
| `internal` | Accessible within the same module (default) |
| `fileprivate` | Accessible within the same file |
| `private` | Accessible within the same scope |

## Error Handling
- `throws` — default when an error carries meaningful information.
- `Optional` — use to express absence (i.e., `nil` is a valid, normal result).
- `Result` — **prohibited**.

## Constraints
- Do not write code for future extensibility.
- Never add code "just in case" — only implement what is explicitly required.
- One class or struct per file, and one test struct per file (matching the type under test).
- After writing unit tests, always run them and confirm they pass before finishing.
- If a test run does not finish within 1 minute, abort the test execution itself and investigate and fix the cause before retrying.
- After implementing any change, build the project and confirm there are no errors before finishing.
- For specifications, refer to the PDFs placed in the `RFC` directory. Only follow sections describing Client behavior — Relay is out of scope.

## Logging
- Always use `OSLogger` in `Source/Util/OSLogger.swift` for log output.
- Follow the log level guidelines below.

| Level | Role | Example Events |
| :--- | :--- | :--- |
| **TRACE** | Raw network data. Disabled in normal operation. | · Raw bytes sent/received on a stream<br>· QUIC frame-level events |
| **DEBUG** | Detailed state changes for debugging. | · MOQT message contents (parsed fields)<br>· Stream open/close events<br>· Session state transitions |
| **INFO** | Key milestones to monitor in production. | · Connection established/closed<br>· Subscribe/Publish started or completed<br>· Session start and teardown |
| **WARN** | Recoverable issues that require attention. | · Retrying after a transient connection error<br>· Received an unexpected but non-fatal message type<br>· Stream closed by peer earlier than expected |
| **ERROR** | Fatal failures requiring intervention. | · Connection failed after maximum retries<br>· Received a malformed or unrecognized MOQT message<br>· Authentication or TLS handshake failure |
