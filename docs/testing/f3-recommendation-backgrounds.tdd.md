# F3 Recommendation Backgrounds — TDD Evidence

## Source and journey

The guarantees were derived from the approved F3 recommendation-background plan. Normal recommendations keep the paper clear, emphasized recommendations tint only the achievement-name area, and keyboard selection still highlights the complete row.

## RED / GREEN evidence

- RED checkpoint: `638870e test: constrain recommendation background area`.
- RED: the focused test run failed 2 of 2 tests because normal still had a color/default fallback and the README still described four full-row backgrounds.
- GREEN checkpoint: `9d1c483 feat: limit recommendation backgrounds to goal names`.
- GREEN: the focused test run passed 2 of 2 tests; `npm.cmd test` then passed all 148 tests.
- Coverage: `npm.cmd run test:coverage` passed all 148 tests and reported 95.02% lines, 84.41% branches, and 90.63% functions for instrumented JavaScript files.
- Hygiene: `git diff --check` completed without errors before the GREEN checkpoint.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| Normal and unknown tiers do not render recommendation backgrounds | `F3 omits normal backgrounds and colors only the achievement-name area` | source contract | PASS |
| Recommendation tint begins exactly at `nameX` and stops at the current column boundary | `F3 omits normal backgrounds and colors only the achievement-name area` | source contract | PASS |
| Full-row selection renders after recommendation tint and before icons and text | `F3 omits normal backgrounds and colors only the achievement-name area` | source contract | PASS |
| README describes three name-only tints and no tint for normal | `documentation attributes the derived recommendation profile and explains F3 behavior` | documentation contract | PASS |

## Known gap

The repository has no Lua rendering harness. The source-contract suite verifies draw coordinates and ordering, but final pixel appearance should still be checked in-game with a normal row, each colored tier, and a selected row.
