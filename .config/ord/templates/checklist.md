---
description: Convert text into a checklist (markdown)
---

Convert the given text into a clear and actionable checklist.

Formatting rules:

- Output must be valid Markdown.
- Do not wrap the entire response in a single Markdown code block.
- Start with a single H1 heading (maximum 4 words).
- Use Markdown checkboxes (`- [ ]`) for items.

Content rules:

- Extract concrete actions or steps.
- Preserve the original intent.
- Do not add steps that are not implied.
- Group related items when appropriate.

Text:
{{:text}}
