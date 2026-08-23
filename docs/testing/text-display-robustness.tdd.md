# v0.8.1 text display robustness — TDD evidence

## Scope

- Shared native unsmoothed HUD/F3 fonts at 11, 22, and 33 pixels, all drawn at 1:1.
- Binary 11px LanaPixel glyphs with exact nearest-neighbor 2x/3x variants, plus antialiased Source Han fallback glyphs.
- Height-first panel expansion, native-tier fallback, and resolution-, language-, and font-aware pagination.
- Full-width wrapped bilingual achievement conditions and compact reward summaries.
- Independent HUD/F3 native-tier settings, schema 9 persistence, and legacy migration.
- HUD position-preserving tier fallback, 11px left shift, complete-goal pagination, and centered warning fitting.
- A 0–8px integer HUD line-spacing setting used by fitting, pagination, safe bounds, and centered warnings.
- Consistent v0.8.1 metadata and Workshop copy.

## RED

The v0.8.1 release regression suite was run before the font and release-copy fixes:

- Command: `node --test tests/font-assets.test.js tests/mod-contract.test.js`
- Result: 57 tests, 52 passed, 5 failed.
- Three failures proved that the new HUD line-spacing label introduced the missing `距` glyph in all native tiers; two failures proved that public metadata and Workshop copy still exposed 0.7.2.
- RED checkpoint: `04dc53a test: require v0.8.1 release metadata`.

## GREEN

- Focused suite: 88/88 passed.
- Full suite: 107/107 passed with `npm.cmd test`; no skipped tests.
- Coverage suite: 107/107 passed with `npm.cmd run test:coverage`; no skipped tests.
- JavaScript tool coverage: 94.77% lines, 82.61% branches, and 90.32% functions.

All 11/22/33px fonts now contain 1175 runtime glyphs, including `距`. Font contracts verify the
binary hard-edged LanaPixel base, exact nearest-neighbor 2x/3x variants, matching source manifests,
and antialiased Source Han fallback glyphs.

The layout regression measures all 641 Chinese and English conditions at 320×180,
408×270, 480×270, 640×360, 854×480, and 1280×360 ultrawide for all three F3 tiers. It also checks
the longest English condition (#324), the representative long Chinese condition
(#235), glyph coverage, line widths, at least one three-item row, and footer clearance.
HUD coverage verifies native 11/22/33px selection, automatic downgrade at the saved
position, left shift only at the 11px floor, complete target coverage through pagination
at 320×180, safe Y bounds, 0/4/8px line spacing, and all bilingual warning conditions.

## Release verification

- The installation and release mirror contain the same 694 public files with matching SHA-256 hashes.
- `AchievementTracker-v0.8.1.zip` contains the single `achievement_tracker/` root and the same 694 files; every extracted hash matches the release mirror.
- The archive contains no tests, development documentation, `node_modules`, package-manager files, legacy 16px font, or 8/10/12px font assets.
- Archive SHA-256: `7BF04D5C53AA35D5489F043563DD084005B5911EC17A8CF07A5E5B0567200661`.
- The Workshop description is 4869 characters, the cover is 933339 bytes, and the v0.7.1 rollback archive remains present.

## Manual verification still required

Automated tests cannot reproduce the game's final display pipeline. Before Workshop
publication, verify Chinese and English, all three HUD and F3 tiers, HUD page rotation,
windowed and fullscreen modes, and the game's Filter setting on representative hardware.
The native 11/22/33px HUD/F3 atlases prevent fractional scaling of LanaPixel glyph textures themselves;
they cannot bypass filtering applied later by the game, graphics driver, or display.
