---
name: lint-claude
description: Use when editing or creating CLAUDE.md — validates conventions
---

When editing or creating CLAUDE.md, validate:

1. **Line count:** Must be under 200 lines
2. **Constraint pattern:** Every rule must follow `.claude/rules/rule-style.md`
3. **Index only:** Flag any rule that contains detailed specs — those belong in `.claude/rules/`
4. **Worth it:** Every rule should fail the test "Would Claude actually get this wrong without it?" — flag any that wouldn't

Output a pass/fail summary with specific line numbers for violations.
