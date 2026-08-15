# F3 fuzzy achievement search — TDD evidence

## Source and journeys

The journeys were derived from the approved implementation plan supplied in the Codex task:

1. Open F3, press `/`, and search achievements by English name, condition, location, required character or item, reward metadata, or numeric ID.
2. Use ordered-character abbreviations such as `mgsn` for `Mega Satan`, with the closest matches ranked first.
3. Combine a live search with the existing Tab reward filter without changing tracking, completion, or character-relevance behavior.
4. Type safely in vanilla, REPENTOGON, and multiplayer sessions without sending the typing player's keys to gameplay or blocking another controller.

## RED / GREEN evidence

- RED: `npm.cmd test` executed 34 tests with 31 passing and 3 failing. The failures covered the absent catalog scorer, F3 search state/input lifecycle, and localized input suppression.
- GREEN: `npm.cmd test` executed the same 34 tests with all 34 passing.
- Coverage: `npm.cmd run test:coverage` reported 34 passing tests and 100% line, branch, and function coverage for the Node contract suite.
- Hygiene: `git diff --check` completed with no whitespace errors.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| Search indexes bilingual names/details, achievement identifiers, and reward metadata and returns deterministic scores | `catalog fuzzy search indexes bilingual copy and reward metadata with scores` | contract | PASS |
| `/`, A–Z, 0–9, Space, Backspace, Delete, the 48-character limit, and Tab-filter intersection are wired into F3 state | `F3 search uses slash without Ctrl or F and combines with category filtering` | contract | PASS |
| Search prompt, result count, empty state, and focused controls are localized; analog hooks return zero while boolean hooks return false | `F3 search renders localized status and suppresses only the typing player's actions` | contract | PASS |
| Existing pause, tracking, reward rendering, completion ordering, and transformation relevance contracts remain intact | complete `npm.cmd test` suite | regression | PASS |
| Newly added Chinese UI glyphs ship in the bundled LanaPixel atlas | font regeneration plus bundled font asset tests | resource | PASS |

## 2026-08-15 slash shortcut and ivory palette regression

- RED: `npm.cmd test` executed 35 tests with 32 passing and 3 failing. The failures covered the old Ctrl/F shortcut, dark F3 ink palette, and inline HUD colors.
- GREEN: `npm.cmd test` executed the same 35 tests with all 35 passing.
- Coverage: `npm.cmd run test:coverage` reported 35 passing tests and 100% line, branch, and function coverage for the Node contract suite.
- Hygiene: `git diff --check` completed with no whitespace errors.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| `/` focuses search without polling either Ctrl key or the standalone F key | `F3 search uses slash without Ctrl or F and combines with category filtering` | contract | PASS |
| F3 uses bright ivory primary text and lighter completed, convertible, and dimmed states | `F3 visual menu filters rewards and renders condition-to-reward details` | visual contract | PASS |
| HUD title, body, and controls use the ivory palette while completion and failure retain distinct bright colors | `HUD uses the ivory palette while retaining bright completion and failure states` | visual contract | PASS |

## Known gaps

The repository has no standalone Lua runtime or Isaac automation harness. The contract suite validates the shipped Lua/resource structure, but final visual and gameplay verification still requires an in-game pass for representative queries (`isaac`, `missing poster`, `sacrifice room`, `mega satan`, `mgsn`, `628`, and `item`) in Chinese/English, vanilla/REPENTOGON, and single-player/multiplayer configurations.

Git checkpoint commits were not created because repository metadata is read-only in this workspace; RED and GREEN evidence is preserved in this report instead.
