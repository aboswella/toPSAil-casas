Task ID:
baseline-smoke-runner

Goal:
Create the smallest Tier 0 smoke runner that confirms unchanged toPSAil examples can run.

Allowed files:
- scripts/run_smoke.m
- tests/README.md
- scripts/README.md
- docs/KNOWN_UNCERTAINTIES.md only if the audit found a blocker

Forbidden files:
- 1_config/
- 2_run/
- 3_source/
- 4_example/
- 5_reference/
- 6_publication/
- params/
- cases/
- validation/manifests/

Source basis:
- AGENTS.md
- docs/TEST_POLICY.md
- docs/TASK_PROTOCOL.md
- completed read-only audit from .codex/prompts/00_readonly_audit.md

Preconditions:
- The read-only audit has identified how original toPSAil examples are run.
- MATLAB is available.

Required implementation:
- Add a minimal smoke runner that exercises an original toPSAil example path identified by the audit.
- Keep it Tier 0 only.
- Do not add validation cases, parameter packs, or model changes.

Required tests:
- In MATLAB: addpath(genpath(pwd)); run("scripts/run_smoke.m");

Runtime limit:
- Keep the smoke runner short enough for routine default use.

Stop conditions:
- Stop if the audit has not identified a reliable original example command.
- Stop if MATLAB cannot run.
- Stop if implementation would require editing toPSAil core files.
- Stop if the smoke runner would need to include Casas, Schell, Delgado, sensitivity, or optimisation work.

Final report must include:
- task objective;
- files inspected;
- files changed;
- commands run;
- tests passed;
- tests failed;
- unresolved uncertainties;
- whether any toPSAil core files changed;
- whether any validation numbers changed;
- next smallest task.
