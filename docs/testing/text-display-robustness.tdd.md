# 0.7.2 text display robustness — TDD evidence

## Scope

- Shared native unsmoothed HUD/F3 fonts at 11, 22, and 33 pixels, all drawn at 1:1.
- Binary 11px LanaPixel glyphs with exact nearest-neighbor 2x/3x variants, plus antialiased Source Han fallback glyphs.
- Height-first panel expansion, native-tier fallback, and resolution-, language-, and font-aware pagination.
- Full-width wrapped bilingual achievement conditions and compact reward summaries.
- Independent HUD/F3 native-tier settings and schema 7 to 8 migration.
- HUD position-preserving tier fallback, 11px left shift, complete-goal pagination, and centered warning fitting.
- Consistent 0.7.2 metadata and Workshop copy.

## RED

The focused regression suite was run before implementation:

- Command: `node --test tests/text-layout.test.js tests/font-assets.test.js tests/mod-contract.test.js tests/achievement-import-contract.test.js tests/save-importer.test.js`
- Result: 87 tests, 75 passed, 12 failed.
- Failures covered the absent schema 8 migration, legacy 16px HUD assets and runtime scaling, native-tier HUD layout and pagination, importer schema, MCM options, and updated 0.7.2 documentation.

## GREEN

- Focused suite: 87/87 passed.
- Full suite: 106/106 passed with `npm.cmd test`.
- Coverage suite: 106/106 passed with `npm.cmd run test:coverage`.
- JavaScript tool coverage: 94.77% lines, 82.61% branches, and 90.32% functions.

The layout regression measures all 641 Chinese and English conditions at 320×180,
408×270, 480×270, 640×360, 854×480, and 1280×360 ultrawide for all three F3 tiers. It also checks
the longest English condition (#324), the representative long Chinese condition
(#235), glyph coverage, line widths, at least one three-item row, and footer clearance.
HUD coverage verifies native 11/22/33px selection, automatic downgrade at the saved
position, left shift only at the 11px floor, complete target coverage through pagination
at 320×180, safe Y bounds, and all bilingual warning conditions.

## Manual verification still required

Automated tests cannot reproduce the game's final display pipeline. Before Workshop
publication, verify Chinese and English, all three HUD and F3 tiers, HUD page rotation,
windowed and fullscreen modes, and the game's Filter setting on representative hardware.
The native 11/22/33px HUD/F3 atlases prevent fractional scaling of LanaPixel glyph textures themselves;
they cannot bypass filtering applied later by the game, graphics driver, or display.
