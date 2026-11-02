# Code Review

> Indexed from `AGENTS.md`, which says when to read this file. Paths here are written from the folder `AGENTS.md` is in, as there.

When asked to "do a code review", follow this process:

### Categories to Evaluate
1. **Bugs** — logic errors, copy-paste mistakes, typos
2. **Security** — auth gaps, data exposure, input validation, secrets in source control
3. **Error Handling** — unhandled throws, force unwraps, silent failures, missing edge cases
4. **Deprecated APIs**
5. **Performance** — redundant computation, missing caching, expensive operations
6. **Style** — inconsistencies with the rest of the existing codebase
7. **Licensing** — attribution, copyright headers, commercial risks

### Output Format
Present findings as a numbered table with columns: ID, Category, Priority, Summary, File(s). Use short IDs by category (B1, S1, E1, D1, P1, C1, L1). Prioritize bugs and security first.

### Cross-Referencing
Before reporting a finding, cross-reference it against existing GitHub issues (open and closed) and prior code-review dispositions; omit anything already tracked or dispositioned won't-fix unless circumstances materially changed. Focus on genuinely new findings.

### Workflow
1. Explore the repo, cross-reference, then present the filtered findings table.
2. Discuss each finding with the user — they decide fix/close/defer.
3. For each fix: edit → build → commit → push.
4. After each commit, regenerate the table with an added Status column (keep all original columns — the table must be self-contained).
