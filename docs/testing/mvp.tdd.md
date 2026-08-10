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

### Chinese HUD and MCM display settings

- RED: `npm.cmd test` — 6 passed, 3 failed because the HUD had no Unicode font/condition rendering, MCM had no language/size/position controls, and storage had no `fontScale` field.
- GREEN: the HUD and in-run menu now share the built-in LanaPixel Unicode renderer, persistent rows show localized `detail` conditions, and MCM exposes bounded language, scale, X, and Y settings.

### Chinese F3 menu font regression

- Root cause: v0.2.0 attempted to load `font/lanapixel.fnt`; in Repentance the Chinese LanaPixel asset resides in the DLC3 Chinese resource package.
- RED: `npm.cmd test` — 9 passed, 1 failed because the renderer neither referenced `resources-dlc3.zh/font/lanapixel.fnt` nor handled a failed font load.
- GREEN: `npm.cmd test` — 10 passed. The renderer checks `Font:Load`, tries the Repentance+ common path second, and resolves to visible English text if neither CJK path exists.

### Repentance+ Chinese font compatibility

- RED: `npm.cmd test` — 10 passed, 1 failed because Repentance+ installations without a mounted Chinese language pack had no compatible external CJK font path.
- GREEN: `npm.cmd test` — 11 passed. The loader now tries the EID Simplified Chinese font in both Workshop and manual-install folder layouts after the two game-resource paths.

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
| 8 | Chinese text uses LanaPixel with UTF-8 scaled rendering | `tests/mod-contract.test.js` | rendering contract | PASS |
| 9 | MCM exposes bounded language, font-size, X, and Y controls | `tests/mod-contract.test.js` | integration contract | PASS |
| 10 | Chinese mode loads the DLC3 font and cannot select an unloaded font | `tests/mod-contract.test.js` | regression contract | PASS |
| 11 | Repentance+ can use an installed EID Simplified Chinese font | `tests/mod-contract.test.js` | compatibility contract | PASS |

## Known gaps

- The workstation has no native Lua/LuaJIT executable, and downloading the optional Fengari test runtime timed out. The suite therefore validates source and integration contracts rather than executing Lua statements.
- Final runtime validation must be performed inside Repentance by enabling the mod, starting a run, opening `F3`, and checking `log.txt` for Lua errors.
- Vanilla Repentance cannot expose all achievement and completion-mark state. Guidance-only goals will gain deeper automatic sensors incrementally; already-unlocked filtering requires REPENTOGON or Repentance+.
