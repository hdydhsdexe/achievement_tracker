# Completion Tracking and New-Run Cleanup: TDD Evidence

## Source and User Journeys

The journeys were derived from the user-approved implementation plan in this task:

1. Every newly completed catalog achievement is announced in green for the rest of the current room.
2. Completed ordinary goals and route members leave the tracker automatically; an empty route ends.
3. F3 moves completed achievements to its completed group and does not allow them to be tracked again.
4. A non-continued game clears the old route and removes goals that cannot be completed under the starting character, mode, difficulty, or route state.
5. Historical completions and continued games do not replay completion notices or receive new-run filtering.

## RED Evidence

- `173e20d test: specify completion tracking cleanup`
  - `node --test tests/completion-tracking.test.js`
  - Result before implementation: 0 passed, 6 failed.
  - Missing behavior: bulk tracker removal, completion transition state, HUD notices, F3 read-only completion rows, and new-run filtering.
- `7a8193b test: align new-run route lifecycle`
  - `node --test tests/completion-tracking.test.js tests/route-recommendations.test.js`
  - Result before implementation: 8 passed, 7 failed.
  - Added the requirement that every non-continued start clears stale route tracking before selecting a fresh recommendation.

## GREEN Evidence

| Guarantee | Test target | Type | Result |
|---|---|---|---|
| Ordinary goals and route members are removed together; the final member ends the route | `completion-tracking.test.js` | Core contract | PASS |
| New completion transitions enqueue one notice in catalog order and prune matching tracked IDs | `completion-tracking.test.js` | Integration contract | PASS |
| Notices are green, bilingual, rendered before normal HUD content, and cleared on the next room | `completion-tracking.test.js` | HUD integration | PASS |
| Completed F3 rows remain at the end and cannot be tracked again | `completion-tracking.test.js` | Menu integration | PASS |
| New starts filter completion, challenge, unlock permission, character conversion, difficulty, and route failure conditions | `completion-tracking.test.js` | Lifecycle integration | PASS |
| Multiple completion notices survive 320x180 pagination without splitting or loss | `text-layout.test.js` | Layout simulation | PASS |

- Focused GREEN: `node --test tests/completion-tracking.test.js tests/route-recommendations.test.js` — 15 passed, 0 failed.
- Complete GREEN: `npm.cmd test` — 179 passed, 0 failed.
- Coverage: `npm.cmd run test:coverage` — 179 passed, 0 failed; lines 95.02%, branches 84.41%, functions 90.63%.

## Known Gap

The automated environment does not include the game's Lua runtime. An in-game smoke test should complete one tracked and one untracked achievement in the same room, finish members of a multi-goal route, enter another room, start a new character/run, and continue an existing run to verify callback timing and persisted tracker state.
