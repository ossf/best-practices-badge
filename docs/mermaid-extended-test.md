# Mermaid v11.3.0+ Feature Support Test

This file is designed to test if the current Markdown environment (like GitHub or VS Code) supports the **Expanded Node Shapes** introduced in Mermaid version 11.3.0, specifically the new `@{ shape: ... }` syntax.

## Basic mermaid test

```mermaid
flowchart TD
    A([Start]) --> B{Logged in?}
    B -- Yes --> C[View Dashboard]
    B -- No --> D[/Login Form/]
    D --> E[(User DB)]
    E --> B
    C --> F([End])
```

## Mermaid v11.3.0+ Shape Support Test

If your renderer supports the latest Mermaid features, the diagram below should display distinct shapes like a **cloud**, a **cylinder**, a **document**, and a **lightning bolt**.

If your rendered instead displays something like this:
`Unable to render rich display` ... `No such shape: step.`
then it does not.

As of 2026-02-20, it appears GitHub doesn't support this.
GitHub instead says:

> For more information, see https://docs.github.com/get-started/writing-on-github/working-with-advanced-formatting/creating-diagrams#creating-mermaid-diagrams

```mermaid
---
config:
  look: handDrawn
  theme: neutral
---
flowchart TD
    %% Version Check (Displays version inside the diagram if supported)
    V@{ shape: lean-right, label: "Checking Mermaid Version..." }

    %% New Shape Syntax (v11.3.0+)
    Cloud@{ shape: cloud, label: "Cloud Storage" }
    DB@{ shape: cyl, label: "Database" }
    Doc@{ shape: doc, label: "User Manual" }
    Comm@{ shape: lightning-bolt, label: "Fast Comm" }
    Step@{ shape: step, label: "Next Step" }

    %% Traditional shapes for comparison
    Start([Start Loop])
    Choice{Decision?}

    %% Connections
    V --> Start
    Start --> Cloud
    Cloud --> Choice
    Choice -- Yes --> DB
    Choice -- No --> Doc
    DB --> Comm
    Doc --> Step
    Comm --> EndNode@{ shape: stop, label: "System Exit" }
    Step --> EndNode
```
