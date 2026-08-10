# Achievement Tracker MVP — TDD evidence

## Source

The journeys were derived from the user-approved MVP plan on 2026-08-10. No external plan file was supplied.

## User journeys

1. A player can select several goals during a run and keep seeing them on the HUD.
2. A player can keep the same tracked goals across runs and game launches.
3. A player receives a deduplicated warning when a deadline is close or a restriction has been broken.
4. A player can configure the tracker without Mod Config Menu and gets richer settings when it is present.

## RED → GREEN

- RED: `npm.cmd test` — 0 passed, 6 failed because the entry point, catalog, tracking core, warning core, UI, and storage implementation did not exist.
- GREEN: `npm.cmd test` — 7 passed, 0 failed after implementing the first vertical slice and the collected-pickup sensor.
- Coverage command: `npm.cmd run test:coverage` — 7 passed. The reported 100% covers the JavaScript contract-test harness only; it must not be interpreted as Lua statement coverage.

## Test specification

| # | Guarantee | Test | Type | Result |
|---|---|---|---|---|
| 1 | Metadata, mod registration, and required callbacks are wired | `tests/mod-contract.test.js` | integration contract | PASS |
| 2 | At least 15 unique bilingual goals ship in the catalog | `tests/mod-contract.test.js` | data contract | PASS |
| 3 | Tracking has uniqueness and maximum-count guards | `tests/mod-contract.test.js` | static behavior contract | PASS |
| 4 | Deadline, eligibility failure, reset, and deduplication paths exist | `tests/mod-contract.test.js` | static behavior contract | PASS |
| 5 | Restriction tracking reacts to the pickup Collect animation | `tests/mod-contract.test.js` | API contract | PASS |
| 6 | In-run menu/HUD work independently of optional MCM | `tests/mod-contract.test.js` | integration contract | PASS |
| 7 | Save data uses defensive JSON decoding and a schema version | `tests/mod-contract.test.js` | storage contract | PASS |

## Known gaps

- The workstation has no native Lua/LuaJIT executable, and downloading the optional Fengari test runtime timed out. The suite therefore validates source and integration contracts rather than executing Lua statements.
- Final runtime validation must be performed inside Repentance by enabling the mod, starting a run, opening `F3`, and checking `log.txt` for Lua errors.
- Vanilla Repentance cannot expose all achievement and completion-mark state. Guidance-only goals will gain deeper automatic sensors incrementally; already-unlocked filtering requires REPENTOGON or Repentance+.
