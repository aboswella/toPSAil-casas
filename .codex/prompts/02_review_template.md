Review the current diff.

Do not edit files unless explicitly instructed.

Check:
1. Did the changes stay within the task scope?
2. Were toPSAil core files modified?
3. Were physics, numerics, metrics, and validation thresholds kept separate?
4. Are source claims supported by docs/workflow/, docs/SOURCE_LEDGER.md, or case specs?
5. Are the tests meaningful or tautological?
6. Are any validation changes explained?
7. For Yang four-bed work, did the changes preserve explicit direct transfers, no dynamic internal tanks, no shared header inventory, no global four-bed RHS/DAE, and no core adsorber-physics rewrite?
8. For Yang four-bed work, did the changes keep final FI/batch ownership boundaries clear and treat WP1-WP5 materials as legacy?
9. What should be reverted or split into a later task?
10. What is the next smallest useful task?

Report findings first, ordered by severity.
If there are no findings, say so and note remaining test gaps or residual risk.
