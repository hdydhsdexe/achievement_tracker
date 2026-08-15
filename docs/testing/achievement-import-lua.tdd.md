# Achievement import Lua integration — TDD evidence

## Source and journey

The journey was derived from the approved achievement-save import plan: after a user imports a `persistentgamedata*.dat` snapshot, the Mod must preserve it as schema v4 and use its `achievementId` values as authoritative without breaking legacy inference.

## RED / GREEN evidence

| Guarantee | Test | RED | GREEN |
|---|---|---|---|
| Schema v4 validates, normalizes, loads, and saves `achievementImport` | `tests/achievement-import-contract.test.js` | `node --test tests/achievement-import-contract.test.js`: 0 pass, 3 fail | same command: 3 pass, 0 fail |
| In-range imported false overrides old observation and reward inference | same file | included in initial 0/3 RED | included in initial 3/3 GREEN |
| Later runtime observations cannot overwrite either imported true or false | same file | expanded suite: 3 pass, 1 fail | expanded suite: 4 pass, 0 fail |
| Startup and every observation entry point receive the loaded snapshot | same file | expanded suite: 3 pass, 1 fail | expanded suite: 4 pass, 0 fail |
| Achievement ID 0 is rejected consistently with the save parser | same file | boundary revision: 1 pass, 3 fail | boundary revision: 4 pass, 0 fail |
| Oversized files, JSON, counts, and snapshots are rejected before expensive processing | both import test files | limit revision: 18 pass, 4 fail | limit revision: 22 pass, 0 fail |

## Final validation

- `npm test`: 59 pass, 0 fail.
- `npm run test:coverage`: 59 pass, 0 fail; executable JavaScript coverage was 92.45% lines, 89.87% branches, and 100% functions.
- `git diff --check -- scripts/core/storage.lua scripts/core/unlocks.lua main.lua tests/achievement-import-contract.test.js`: pass.

## Known gap

The repository has no Lua runtime test harness. The Lua integration is protected by source-contract tests; executable coverage is reported only for the browser importer JavaScript. In-game verification remains appropriate for the final manual acceptance pass.
