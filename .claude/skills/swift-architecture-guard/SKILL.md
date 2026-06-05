---
description: Enforces modern iOS architecture patterns, Swift 6 concurrency rules, and SwiftUI best practices.
user-invocable: true
disable-model-invocation: false
---

# Modern iOS Architecture Guard

When writing, refactoring, or reviewing iOS code, you must strictly adhere to the following architectural constraints.

## 1. Concurrency & State Management
*   **Swift 6 Concurrency:** Always use modern structured concurrency (`async/await`, `Task`, `TaskGroup`). Never use legacy completion handlers or Combine `Future` blocks unless explicitly interacting with an older legacy framework.
*   **MainActor Thread Safety:** Ensure UI-binding classes (like ViewModels) or state-updating functions are explicitly decorated with `@MainActor`.
*   **Modern SwiftUI State:** 
    *   Use `@State` strictly for local, value-type view-private state.
    *   Use `@Observable` (SwiftUI 4+) for reference-type ViewModels instead of the legacy `ObservableObject` and `@Published`.

## 2. SwiftUI Layout & Performance
*   **Body Extraction:** Keep the main `var body: some View` clean. If a view exceeds 40 lines, extract subviews into standalone structs or `@ViewBuilder` private properties to keep the view hierarchy lightweight.
*   **Apple HIG Compliance:** Adhere to Apple’s Human Interface Guidelines. Ensure interactive targets are at least 44x44 points, support Dynamic Type out of the box, and naturally adapt to Dark Mode.

## 3. Data & Networking Layers
*   **SwiftData:** Default to SwiftData (`@Model`, `ModelContext`) for local persistence instead of Core Data.
*   **Type-Safe Networking:** Wrap network calls using async/await with custom `Decodable` structs. Ensure errors are explicitly thrown via a typed `Error` enum rather than swallowing exceptions.

## 4. Execution Workflow
When the user asks you to implement a feature or write Swift code:
1. First, check the existing project files for established architecture.
2. Draft the implementation adhering to these guidelines.
3. Automatically run `swift test` or build the target using `xcodebuild` if a testing pipeline is available, confirming there are no compiler warnings or strict concurrency violations before finalizing.
