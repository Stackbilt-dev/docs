---
title: "cc-taskrunner"
description: "Autonomous task queue for Claude Code with safety hooks, branch isolation, and automatic PR creation. Queue tasks. Go to sleep. Wake up to PRs."
section: "ecosystem"
order: 16
color: "#ef4444"
tag: "16"
lastVerified: "2026-06-28"
---

# cc-taskrunner

**GitHub:** [Stackbilt-dev/cc-taskrunner](https://github.com/Stackbilt-dev/cc-taskrunner) · Apache-2.0

Part of the [Stackbilt ecosystem](/ecosystem). Autonomous task queue for [Claude Code](https://claude.ai/code) with safety hooks, branch isolation, and automatic PR creation. Integrates with [Charter CLI](/getting-started)'s `charter blast` for blast-radius gating before any change touches code.

Queue tasks. Go to sleep. Wake up to PRs.

```
$ ./taskrunner.sh add "Write unit tests for the auth middleware"
Added task a1b2c3d4: Write unit tests for the auth middleware

$ ./taskrunner.sh --max 5
[09:15:00] cc-taskrunner starting
[09:15:01] ┌─ Task: Write unit tests for the auth middleware
[09:15:01] │  Branch: auto/a1b2c3d4
[09:15:01] │  Starting Claude Code session...
[09:17:42] │  Pushing 3 commit(s) to auto/a1b2c3d4...
[09:17:44] │  PR created: https://github.com/you/repo/pull/42
[09:17:44] └─ COMPLETED
```

---

## Why It Exists

Claude Code is powerful in interactive sessions but has no built-in way to:

- **Queue tasks** and run them unattended (overnight, during meetings, in CI)
- **Isolate changes** on branches so autonomous work never touches main
- **Block dangerous operations** when nobody's watching
- **Create PRs automatically** so you review diffs, not raw commits

cc-taskrunner fills that gap — the execution layer between "Claude can write code" and "Claude can ship code safely."

---

## Setup

**Requirements:** bash, python3, `gh` CLI, `claude` CLI, git.

```bash
git clone https://github.com/Stackbilt-dev/cc-taskrunner.git
cd cc-taskrunner

# Add a task
./taskrunner.sh add "Your task description"

# Run up to 5 tasks
./taskrunner.sh --max 5

# Run in continuous loop mode
./taskrunner.sh --loop
```

Tasks are stored in a `queue.json` file. Each task runs on its own `auto/{task-id}` branch and creates a PR when complete.

---

## Safety Hooks

Pre-flight bash hooks run before Claude Code starts each task. Hooks can inspect the task description and abort before any code is written. Built-in integrations:

- **`charter blast`** — Charter CLI's blast-radius gate. Estimates scope of change before dispatch. Blocks tasks that exceed configured risk thresholds.
- **Operation blocklist** — hooks block destructive shell operations (`rm -rf`, force-push, `--no-verify`) at the OS level rather than relying on prompt discipline alone.

---

## cc-taskrunner vs. Claude Code Routines

In April 2026 Anthropic shipped [Claude Code Routines](https://claude.ai/code) — saved configurations that run on Anthropic's cloud infrastructure on a schedule, API trigger, or GitHub event. Both tools have a place:

| | cc-taskrunner | Claude Code Routines |
|---|---|---|
| **Where it runs** | Your machine | Anthropic-managed cloud |
| **Trigger** | Manual / 1-min polling loop | Schedule (1h min), API, or GitHub event |
| **Local filesystem** | Full access | Cloned-repo only |
| **Runs while laptop is closed** | No | Yes |
| **Queue management** | JSON file, dependencies, FIFO | One prompt per routine |
| **Branch isolation** | `auto/{task-id}` per task | `claude/*`-prefixed branches |
| **Pre-flight safety hooks** | Bash hooks, blast-radius gate | Permission-mode-less by design |
| **Setup** | bash + python3 + `gh` + clone | claude.ai account |

**Use cc-taskrunner when:** you need queue management, sub-hour polling, local filesystem access, or hook-level safety enforcement.

**Use Routines when:** the work fits a single repeating schedule/event trigger and needs to run while your machine is off.

---

## Honest Disclosure

Stackbilt currently runs taskrunner in **paused** mode and uses Routines for several scheduled workloads (autonomous heartbeat triage, weekly cross-repo pattern scans) — because those workloads fit the routine substrate better. Both tools are complementary. If you're starting fresh and your work fits the schedule/event model, try Routines first. If you need queue management, sub-hour polling, or local filesystem access, taskrunner is the right tool.
