# F3 achievement icons TDD evidence

## Source and user journeys

The source plan was approved in the Codex conversation on 2026-08-22. It
requires every F3 achievement to use the same bundled wiki-style icon in the
12px list and 30px detail view, without REPENTOGON or runtime network access,
while retaining the existing semantic icon chain as a failure fallback.

## RED and GREEN evidence

- RED: `node --test tests/achievement-icons.test.js` executed eight new
  contracts. All eight failed because the generator, icon manifest, ANM2,
  achievement ID forwarding, and notices did not exist.
- GREEN: `npm.cmd test` passed all 89 tests after the implementation and the
  MediaWiki-normalized filename regression were added.
- Coverage: `npm.cmd run test:coverage` passed all 89 tests and reported 94.77%
  lines, 82.61% branches, and 90.32% functions for executable JavaScript.

## Test specification

| What is guaranteed | Test | Type | Result |
|---|---|---|---|
| Cargo aliases are joined by achievement ID and the newest DLC icon wins | `achievement icon generator joins aliases...` | unit | PASS |
| Missing/duplicate IDs, bad PNGs, wrong dimensions, failed requests, and normalized MediaWiki titles are handled explicitly | generator error and normalization tests | unit | PASS |
| A complete mocked 641-icon generation writes deterministic numbered files and a manifest | `generator completes an offline 641-icon integration run...` | integration | PASS |
| The bundled manifest covers exactly IDs 1–641 and every PNG is 64x64 with a matching SHA-256 | bundled manifest and hash tests | asset contract | PASS |
| F3 forwards `achievementId`, prefers the bundled art at both sizes, remains offline, and preserves semantic fallbacks | `F3 prefers achievement ids...` and existing renderer contracts | integration contract | PASS |
| Existing menu, tracking, search, native entity, and save-import behavior remains intact | complete `npm.cmd test` suite | regression | PASS |

## Manual evidence and remaining check

Icons #1, #336, and #641 were visually inspected after generation and matched
the expected square achievement-badge style. Live-game confirmation remains for
scrolling all F3 pages, checking status tints, and comparing the 12px and 30px
rendering because the Node suite cannot execute the Isaac renderer.
