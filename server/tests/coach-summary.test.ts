import assert from "node:assert/strict";
import { test } from "node:test";
import { freshData, validateData } from "../../src/storage.js";
import {
  bearerCoachToken,
  coachSummary,
  coachTokenDigest,
  InvalidCoachTokenLabel,
  isCoachTokenId,
  normaliseCoachLabel,
  parseSummaryDays,
} from "../coachTokens.js";
import { securityEvent } from "../securityEvents.js";
import type { WorkspaceData } from "../schema.js";

const token = `forma_coach_${"A".repeat(43)}`;

test("bearer parsing accepts only a single well-formed FORMA coach token", () => {
  assert.equal(bearerCoachToken(`Bearer ${token}`), token);
  assert.equal(bearerCoachToken(`  Bearer   ${token}  `), token);
  for (const value of [
    undefined,
    "",
    token,
    `Basic ${token}`,
    `Bearer ${token} extra`,
    `Bearer ${token.slice(0, -1)}`,
    `Bearer ${token}=`,
    "Bearer forma_coach_",
    `Bearer ${"x".repeat(200)}`,
    "Bearer other",
  ])
    assert.equal(bearerCoachToken(value), null, String(value));
  assert.equal(bearerCoachToken([`Bearer ${token}`]), token);
});

test("token digests are keyed by the server secret and ids have a fixed shape", () => {
  const a = coachTokenDigest(token, "secret-one");
  assert.match(a, /^[a-f0-9]{64}$/);
  assert.notEqual(a, coachTokenDigest(token, "secret-two"));
  assert.notEqual(
    a,
    coachTokenDigest(`forma_coach_${"B".repeat(43)}`, "secret-one"),
  );
  assert.equal(isCoachTokenId("a".repeat(22)), true);
  assert.equal(isCoachTokenId("a".repeat(21)), false);
  assert.equal(isCoachTokenId("a".repeat(21) + "/"), false);
  assert.equal(isCoachTokenId(42), false);
});

test("labels follow the profile-name rules and the history window is bounded", () => {
  assert.equal(normaliseCoachLabel("  Claude coach  "), "Claude coach");
  for (const value of [
    "",
    " ",
    "x".repeat(61),
    "bad\u200bname",
    "line\nbreak",
    7,
  ])
    assert.throws(() => normaliseCoachLabel(value), InvalidCoachTokenLabel);
  assert.equal(parseSummaryDays(undefined), 28);
  assert.equal(parseSummaryDays("7"), 7);
  assert.equal(parseSummaryDays("365"), 365);
  for (const value of ["0", "366", "1000", "-1", "7.5", "abc", "", ["7"]])
    assert.equal(parseSummaryDays(value), null, String(value));
});

test("the coach summary exposes training data only and computes bests and weekly totals", () => {
  const base = freshData() as WorkspaceData;
  const [routine] = base.routines;
  const loadReps = routine.exercises.find((item) => item.weight !== undefined)!;
  const now = Date.parse("2026-10-18T09:00:00.000Z");
  const day = 24 * 60 * 60 * 1000;
  const session = (id: string, date: number, weight: number, reps: number) => ({
    id,
    name: routine.name,
    routineId: routine.id,
    startedAt: date - 3600_000,
    notes: `note ${id} ${"n".repeat(2000)}`,
    restSeconds: 90,
    restEnd: null,
    restPaused: null,
    date: new Date(date).toISOString(),
    duration: 3600,
    exercises: [
      {
        exerciseId: loadReps.exerciseId,
        sets: [
          { weight, reps, done: true },
          { weight: weight + 100, reps: 5, done: false },
        ],
      },
    ],
  });
  const {
    date: _date,
    duration: _duration,
    ...active
  } = session("active", now - 60_000, 1, 1);
  // Validate the fixture so schema defaults apply whatever the current
  // workspace version adds to exercise entries and the profile.
  const data = validateData({
    ...base,
    history: [
      session("old", now - 200 * day, 100, 5),
      session("recent-1", now - 10 * day, 60, 10),
      session("recent-2", now - 2 * day, 62.5, 10),
    ],
    active,
    profile: { ...base.profile, name: "Raouf", goal: 5 },
    schedule: [4, 0, 2],
  }) as WorkspaceData;

  const summary = coachSummary(data, 28, now);
  assert.equal(summary.member.name, "Raouf");
  assert.equal(summary.member.weeklyGoal, 5);
  assert.deepEqual(summary.schedule, ["Monday", "Wednesday", "Friday"]);
  assert.equal(summary.days, 28);
  assert.equal(summary.totalSessions, 3);
  assert.deepEqual(
    summary.sessions.map((item) => item.id),
    ["recent-2", "recent-1"],
  );
  // Catalog names are resolved for the coach; raw IDs stay alongside them.
  assert.notEqual(summary.sessions[0].exercises[0].name, loadReps.exerciseId);
  assert.equal(
    summary.sessions[0].exercises[0].exerciseId,
    loadReps.exerciseId,
  );
  assert.ok(summary.sessions[0].notes.length <= 1000);
  assert.equal(summary.activeWorkout?.name, routine.name);
  const best = summary.personalBests.find(
    (item) => item.exerciseId === loadReps.exerciseId,
  );
  assert.ok(best);
  // Unfinished sets never count; the all-time best comes from the old session.
  assert.equal(best.bestWeight, 100);
  assert.equal(best.estimatedOneRM, 116.7);
  assert.equal(best.lastPerformed, new Date(now - 2 * day).toISOString());
  assert.equal(
    summary.weekly.reduce((n, week) => n + week.sessions, 0),
    2,
  );
  assert.equal(
    summary.weekly.reduce((n, week) => n + week.volume, 0),
    60 * 10 + 62.5 * 10,
  );
  assert.ok(
    summary.routines.every((item) => item.exercises.every((e) => e.name)),
  );
  const serialised = JSON.stringify(summary);
  for (const forbidden of ["email", "revision", "operation", "owner", "userId"])
    assert.equal(serialised.includes(`"${forbidden}"`), false, forbidden);

  const week = coachSummary(data, 7, now);
  assert.deepEqual(
    week.sessions.map((item) => item.id),
    ["recent-2"],
  );
});

test("coach bearer failures and lockouts are distinct security events", () => {
  assert.equal(
    securityEvent("/api/coach/workspace?days=7", 401, "ip", "s")?.event,
    "coach_token_failure",
  );
  assert.equal(
    securityEvent("/api/coach/workspace", 429, "ip", "s")?.event,
    "coach_token_lockout",
  );
  assert.equal(securityEvent("/api/coach/workspace", 200, "ip", "s"), null);
  assert.equal(
    securityEvent("/api/account/coach-tokens", 401, "ip", "s"),
    null,
  );
});
