# Structured Prompt Output Template

Use the following Markdown template when generating the final structured prompt.
All content must be written in **English**, regardless of the language used in the user's original input.

---

## Template

```markdown
## Role
[Define the AI's persona, expertise, and perspective.
 Be specific: e.g., "You are a senior machine learning researcher specializing in time-series analysis."]

## Context
[Provide background information, relevant constraints, and any prior knowledge the AI needs.
 Include: domain, data, environment, audience, or any relevant state.]

## Task
[State the primary task as a clear, actionable imperative.
 Break into numbered sub-steps if the task is multi-part.]

## Constraints
[List rules the AI must follow. Use bullet points.
 Examples: output length limit, forbidden topics, required citations, tone, style.]

## Output Format
[Describe the expected output structure precisely.
 Specify: format (Markdown/JSON/plain text), length, language, sections required, etc.]

## Examples
[Optional. Provide one or more input→output examples to illustrate the expected behavior.
 Omit this section if no examples are needed or available.]
```

---

## Section Guidelines

| Section | Required? | Notes |
|---|---|---|
| Role | ✅ Yes | Always define a specific role; avoid "You are an AI assistant." |
| Context | ✅ Yes | Minimum one sentence; more detail = better output |
| Task | ✅ Yes | Use imperative verbs ("Write", "Analyze", "Summarize") |
| Constraints | ✅ Yes | At least one constraint; add "N/A" only if truly unconstrained |
| Output Format | ✅ Yes | Always specify language (English) and structure |
| Examples | ⬜ Optional | Include when the task involves pattern-matching or formatting |

---

## Quality Checklist

Before outputting the structured prompt, verify:

- [ ] Each section has substantive content (no empty sections)
- [ ] The Role is specific to a domain or skill set
- [ ] The Task is unambiguous and actionable
- [ ] Constraints do not contradict the Task
- [ ] Output Format specifies at minimum: language and structure type
- [ ] The prompt is self-contained (no unexplained references)
