# 0.7.2 text display robustness — TDD evidence

## Scope

- Native unsmoothed F3 fonts at 8, 10, and 12 pixels.
- Resolution-, language-, and font-aware F3 rows and pagination.
- Full-width wrapped bilingual achievement conditions and compact reward summaries.
- Independent HUD/F3 settings, schema 5 to 6 migration, HUD auto-fit, and safe bounds.
- Consistent 0.7.2 metadata and Workshop copy.

## RED

The focused regression suite was run before implementation:

- Command: `node --test tests/text-layout.test.js tests/font-assets.test.js tests/mod-contract.test.js tests/achievement-import-contract.test.js tests/save-importer.test.js`
- Result: 84 tests, 70 passed, 14 failed.
- Failures covered the absent schema 6 migration, F3 font assets and APIs, dynamic pagination/detail layout, HUD fitting, separate MCM controls, importer schema, and 0.7.2 release metadata.

## GREEN

- Focused suite: 85/85 passed.
- Full suite: 104/104 passed with `npm.cmd test`.
- Coverage suite: 104/104 passed with `npm.cmd run test:coverage`.
- JavaScript tool coverage: 94.77% lines, 82.61% branches, and 90.32% functions.

The layout regression measures all 641 Chinese and English conditions at 320×180,
408×270, 480×270, 640×360, and 854×480 for all three F3 sizes. It also checks
the longest English condition (#324), the representative long Chinese condition
(#235), glyph coverage, line widths, at least one three-item row, and footer clearance.

## Manual verification still required

Automated tests cannot reproduce the game's final display pipeline. Before Workshop
publication, verify Chinese and English, all three F3 sizes, HUD 0.5/1/2x, windowed
and fullscreen modes, and the game's Filter setting on representative hardware.
The native F3 atlases prevent fractional scaling of the glyph textures themselves;
they cannot bypass filtering applied later by the game, graphics driver, or display.
