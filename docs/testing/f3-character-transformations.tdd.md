# F3 Potential Character Transformations — TDD Evidence

## Source and journey

The test guarantees were derived from the approved F3 potential-character plan. A player who can change character during the run should see achievements for reachable characters promoted and visually distinguished without losing the current selection.

## RED / GREEN evidence

- RED: `npm.cmd test` ran 31 tests with 26 passing and 5 failing. The failures identified the absent conversion context, three-state ordering, dynamic signature refresh, and convertible UI state.
- Review RED: a completion-state refresh regression was added after independent review and failed with 30 of 31 tests passing before the menu signature fix.
- GREEN: `npm.cmd test` ran the same 31 tests with all 31 passing.
- Coverage: `npm.cmd run test:coverage` reported 100% for the Node contract suite.
- Hygiene: `git diff --check` completed with no errors.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| Ankh, Broken Ankh, Judas' Shadow, Lazarus' Rags, Missing Poster, and Clicker are recognized; swallowed trinkets use `HasTrinket` | `character context includes every supported transformation source` | contract | PASS |
| Multiplayer, normal/tainted Clicker pools, REPENTOGON unlock filtering, vanilla fallback, and transformation chains are represented in one signed context | `character context models Clicker pools, unlock filtering, chains, and multiplayer` | contract | PASS |
| Goals sort current/general → convertible → other → completed | `F3 tracking mode ranks current-character goals and dims other-character goals` | contract | PASS |
| Convertible goals use amber styling, `~`, localized detail text, and character or completion signature changes re-sort while preserving the selected goal | `F3 distinguishes convertible goals and refreshes them without moving the selected goal` | contract | PASS |

## Known gap

The repository has no Lua runtime test harness. The contract suite validates shipped source structure; final visual and gameplay behavior still needs in-game verification with both vanilla Repentance and REPENTOGON.
