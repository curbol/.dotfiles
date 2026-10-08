#!/usr/bin/env node
// keep-going.mjs — hold a longrun open while its checklist still has work.
//
// Registered on Stop by this plugin. Stop fires when the assistant tries to end a
// turn, and a Stop hook may refuse, which is the only mechanism that makes an
// "autonomous" run actually autonomous in an interactive session.
//
// WHY THIS EXISTS
// The skill tells the model to run for hours without human input. Nothing enforced
// it. An interactive turn ends whenever the model stops emitting tool calls, so a
// long run decayed into a supervised one: the model would finish a phase, write a
// progress report, and hand control back. Observed across one real run, the
// instruction to keep going was given three separate times and did not hold, which
// is the signature of a rule that needs a mechanism rather than more emphasis.
//
// INERT UNLESS A RUN IS IN PROGRESS
// It does nothing at all unless $CLAUDE_PROJECT_DIR/.longrun/TASKS.md exists, so a
// session that is not a longrun never sees it. Presence of that file is the opt-in.
//
// THREE ESCAPES, because a hook that cannot be escaped is worse than the problem it
// solves:
//
//   1. .longrun/STOP exists      -> always allow. The kill switch, for the human.
//   2. stop_hook_active          -> always allow. Prevents re-entering on one stop.
//   3. MAX_BLOCKS consecutive    -> always allow. The important one: blocking
//      blocks                       forever on a task the model cannot finish would
//                                   burn tokens producing nothing, which is worse
//                                   than stopping to ask.
//
// It deliberately does NOT block on the presence of parked decisions. Parking
// something for the human and continuing is correct; parking it and stopping is the
// behaviour this exists to prevent.

import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";

const MAX_BLOCKS = 25;

function main() {
  const project = process.env.CLAUDE_PROJECT_DIR || process.cwd();
  const runDir = join(project, ".longrun");
  const tasks = join(runDir, "TASKS.md");
  const stop = join(runDir, "STOP");
  const counter = join(runDir, ".keep-going-count");

  const allow = () => {
    try { if (existsSync(runDir)) writeFileSync(counter, "0"); } catch { /* not worth failing over */ }
    process.exit(0);
  };

  let payload = {};
  try { payload = JSON.parse(readFileSync(0, "utf8") || "{}"); } catch { /* fine */ }
  if (payload.stop_hook_active) allow();

  if (!existsSync(tasks)) allow();
  if (existsSync(stop)) allow();

  const text = readFileSync(tasks, "utf8");
  const remaining = text.split("\n").filter((l) => l.trim().startsWith("- [ ] "));
  if (!remaining.length) allow();

  let count = 0;
  try { count = parseInt(readFileSync(counter, "utf8"), 10) || 0; } catch { count = 0; }
  if (count >= MAX_BLOCKS) allow();
  try {
    mkdirSync(dirname(counter), { recursive: true });
    writeFileSync(counter, String(count + 1));
  } catch { /* not worth failing over */ }

  const next = remaining[0].trim().replace(/^- \[ \] /, "");
  const done = text.split("\n").filter((l) => l.trim().startsWith("- [x] ")).length;

  process.stdout.write(JSON.stringify({
    decision: "block",
    reason:
      `Do not stop. ${remaining.length} of ${done + remaining.length} items remain in ` +
      `.longrun/TASKS.md.\n\nNext: ${next}\n\n` +
      `Continue working through the checklist. Tick each line as you finish it and ` +
      `commit as you go. Do not write a progress report between tasks: the human ` +
      `reads REPORT.md at the end, not a running commentary.\n\n` +
      `If something genuinely needs the human, add it to .longrun/DECISIONS.md and ` +
      `carry on with the next item rather than stopping. To end the run ` +
      `deliberately, create .longrun/STOP.`,
  }));
  process.exit(0);
}

try {
  main();
} catch {
  // A broken hook must never wedge a session.
  process.exit(0);
}
