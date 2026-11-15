---
name: writing-skills
description: Use when adding a new skill to the ai-skills repo or editing an existing one. Covers the folder layout, required SKILL.md frontmatter, how to write a description that triggers reliably, keeping SKILL.md short with detail in references/, and validating before opening a PR.
---

# Writing skills for this repo

## Layout

```
skills/
  <skill-name>/
    SKILL.md            # required
    references/         # optional: longer docs loaded only when needed
    assets/             # optional: templates, JSON, files the skill copies
    scripts/            # optional: scripts the skill runs
```

`<skill-name>` is lowercase kebab-case and matches the `name` in frontmatter.

## SKILL.md

```markdown
---
name: <skill-name>
description: <when to use it, then what it does — one paragraph>
---

# <Title>

<instructions>
```

- **`description` is what decides whether the skill gets used.** Lead with the situations that should trigger it ("Use when…"), name the concrete words a request might contain (e.g. "API key, token, password"), then say what the skill does. Keep it under ~1024 characters.
- The body is instructions for Claude, not an essay: rules first, then steps, then edge cases. Imperative voice.
- Keep SKILL.md under ~300 lines. Move long examples or reference material into `references/` and link to them with a relative path.
- Say *why* for any rule that isn't obvious; it helps the rule get applied sensibly in cases the skill didn't anticipate.
- No credentials, personal data, or machine-specific secrets in any skill file.

## Before opening a PR

```bash
bash scripts/validate-skills.sh
```

It checks every `skills/*/SKILL.md` has frontmatter with a `name` matching its folder and a non-empty `description`. CI runs the same script plus a secret scan.

Then add the skill to the table in the root `README.md` and follow the `git-workflow` skill to open the PR.
