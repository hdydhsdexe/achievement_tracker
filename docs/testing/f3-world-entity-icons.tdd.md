# F3 World Entity Reward Icons — TDD Evidence

## Source and journey

The guarantees were derived from the approved F3 entity-icon plan. A player browsing achievements should see the unlocked pickup, machine, beggar, poop, or Fool's Gold actor in both the 12 px list and 30 px detail views, while replacement mods remain effective because all actors load from the game's virtual filesystem.

## RED / GREEN evidence

- RED: `npm.cmd test` ran 74 tests with 70 passing and 4 failing. The failures identified the absent 23-entry reward map, native actor loader, entity labels, search aliases, cache fields, and safe fallback behavior.
- GREEN: `npm.cmd test` ran the same 74 tests with all 74 passing.
- Coverage: `npm.cmd run test:coverage` ran all 74 tests successfully and reported 92.45% line, 89.87% branch, and 100% function coverage for the executable Node save importer. Lua behavior is guarded by source-contract tests because the repository has no Isaac Lua runtime harness.
- Hygiene: `git diff --check` completed with no errors.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| All 23 achievements map to pickup, slot, or grid metadata at the catalog layer and remain in the Other filter | `F3 maps achievement-unlocked world entities to semantic reward metadata` | contract | PASS |
| Native ANM2 paths, exact animations and frames, cache identity, scaled offsets, and generic-icon fallback are present | `F3 world entity icons use native game actors with static frames and fallback` | contract | PASS |
| Charming Poop replaces the poop sheet and uses `State1` frame 5; Fool's Gold uses `foolsgold` frame 0 | `F3 world entity icons use native game actors with static frames and fallback` | contract | PASS |
| Pickup, machine, and grid labels and search aliases are bilingual without adding a filter tab | `F3 localizes and searches world entity reward kinds without adding filters` | contract | PASS |
| Existing portrait overlays follow the same centered render position | `character reward renderer loads cached vanilla portraits with safe fallbacks` | contract | PASS |

## Known gap

Automated tests cannot render Isaac's virtual resources. Final visual confirmation of actor pivots, texture-replacement compatibility, and status tinting still requires opening F3 in Repentance and checking the 23 achievement IDs at both icon sizes.
