# Codex Task Protocol

Every implementation or audit task must use this structure. A task should be small enough that the final report can clearly say what changed and why.

## Task ID

Unique name.

## Goal

One sentence.

## Allowed files

Explicit list of files or directories that may be edited.

## Forbidden files

Explicit list of files or directories that must not be edited. Include toPSAil core folders unless the task explicitly authorises core work.

## Source basis

Which source or doc justifies the task.

## Preconditions

What must already pass.

## Required tests

Exact commands.

State whether each test is Tier 0, 1, 2, 3, 4, or 5.

## Runtime limit

Expected maximum runtime. Full validation and optimization runs must not be hidden inside default smoke tests.

## Stop conditions

When to stop instead of editing.

Required stop conditions:

- source ambiguity blocks the task;
- required parameter is missing;
- change would touch toPSAil core internals without authorisation;
- validation mismatch has multiple plausible causes;
- test threshold would need to change;
- MATLAB cannot run the required test;
- task would mix validation modes or project stages.

## Report format

Must include:

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

## Review task format

For review-only tasks, do not edit files. Report findings first, ordered by severity, then note any open questions and the smallest next task.
