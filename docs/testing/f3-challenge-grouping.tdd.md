# F3 Challenge Grouping — TDD Evidence

## Source and journey

This behavior was derived from the user's request that achievements unlocked only by completing a challenge belong to F3 group 5 during a normal run. The existing tracked-first rule remains unchanged for non-challenge goals.

## RED / GREEN evidence

- RED checkpoint: `ce16bc8 test: reproduce tracked challenge grouping bug`.
- RED command: `node --test --test-name-pattern "challenge-only goals stay unavailable" tests/unlock-recommendations.test.js` ran the new test and failed because tracking was evaluated before the challenge-mode restriction.
- GREEN checkpoint: `5ea4ef5 fix: keep challenge-only goals in unavailable group`.
- GREEN command: the same focused test passed 1 of 1; `npm.cmd test` then passed all 148 tests.
- Coverage: `npm.cmd run test:coverage` passed all 148 tests and reported 95.02% lines, 84.41% branches, and 90.63% functions for instrumented JavaScript files.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| An unfinished challenge-only goal that is unavailable in the current mode enters group 5 before tracking is considered | `challenge-only goals stay unavailable outside their challenge even when tracked` | source contract | PASS |
| Non-challenge unavailable tracked goals retain the existing tracked-first behavior | `F3 tracking mode keeps non-challenge tracked goals before actionable and unavailable groups` | source contract | PASS |
| A matching challenge run can still expose its own challenge goal | `challenge runs show only their unlock while F3 marks challenge-only unlocks unavailable elsewhere` | source contract | PASS |

## Known gap

The repository has no Lua runtime harness. The source-contract suite verifies the grouping branch and ordering, but final behavior should still be checked in-game by tracking a challenge-only achievement and opening F3 in both a normal run and its matching challenge.
