# F3 achievement reward visual menu — TDD report

## Scope

- Normalize every catalog entry to `reward={kind,id?,enum?}` at load time.
- Render cached vanilla collectible, trinket, and card graphics.
- Render an original five-frame fallback atlas for character, area, challenge,
  feature, and other rewards.
- Keep the 3x9 grid and add category filters, condition-to-reward details, and
  REPENTOGON-aware single-player pausing.

## Journeys covered

1. Open F3 and see 27 reward-oriented entries per page.
2. Press Tab through the twelve reward categories; the compact active label and
   selection reset together.
3. Move with arrow keys and toggle tracking with Enter or Space.
4. Read the selected achievement's condition, confirmation state, reward icon,
   type, and ID.
5. Pause only with REPENTOGON and one unique controller; keep multiplayer and
   vanilla single-player sessions live with an on-screen notice.

## RED evidence

The first `npm.cmd test` run after adding the contracts reported 19 passing and
5 failing tests. The failures covered the then-missing reward resolver, icon
cache, filter/detail UI, and conditional pre-update callback.

## GREEN evidence

- `npm.cmd test`: 24 passed, 0 failed.
- `npm.cmd run test:coverage`: 24 passed, 0 failed; Node reports 100% coverage
  for the JavaScript contract suite.
- The custom ANM2 parses as XML and references assets present in the installed
  game's Resource Extractor file list.
- The fallback atlas is 80x16 pixels and contains five 16x16 frames.

## Remaining manual checks

The Node suite validates Lua/resource contracts but does not instrument or run
Lua inside Isaac. A live-game pass is still needed for Chinese/English rendering,
480x270 and widescreen layouts, font scales 0.5/1/2, all reward kinds, and the
REPENTOGON single-player/multiplayer pause behavior.

Git checkpoint commits were not created because the repository metadata is
read-only in this workspace and the implementation was applied on top of
pre-existing user changes.

## 2026-08-14 overlap, alignment, and contrast regression

Screenshot-driven contracts were added before the fix. The RED run reported
21 passing and 3 failing tests for the missing pause-screen/HUD layering,
neutral item anchor, and high-contrast palette.

The implementation now cancels REPENTOGON's pause-screen render while F3 is
open, renders after the HUD when that callback exists, blocks the pause action
while the menu owns Escape, and refuses to stack F3 over an already-open vanilla
pause screen. Collectibles and trinkets use a centered custom 32x32 animation
instead of the hovering world animation. Paper is fully opaque with a stronger
backdrop; estimated contrast against the parchment ranges from 4.99:1 to 9.68:1
across the menu palette.

## 2026-08-14 centered safe-panel regression

The reference-UI pass added contracts for a centered 64%-width paper panel,
relative layout coordinates, panel-only shadow rendering, and suppression of
the normal map action while Tab changes filters. The RED run reported 22
passing and 2 failing tests; the completed implementation returned the suite to
green. At a 480-pixel internal width the panel is approximately 307 pixels wide
with 86-pixel side clearances; at 408 pixels it uses the 270-pixel minimum with
69-pixel clearances for the left and right HUD regions.

## 2026-08-17 priority and navigation regression

The journeys were derived from the approved Codex implementation plan: tracked
achievements must lead the F3 list, held arrows must repeat without wrapping,
and mouse hover/click must select and toggle visible tiles without affecting
another controller.

- RED: `npm.cmd test` ran 69 tests with 65 passing and 4 failing. The intended
  failures covered the absent tracked bucket, priority-first search ordering,
  held-arrow timing, and mouse hit/click handling.
- GREEN: `npm.cmd test` ran the same 69 tests with all 69 passing.
- Review RED/GREEN: input review found real-time arrow/Space leakage and a
  same-frame keyboard/mouse targeting ambiguity. The added contract ran 70
  tests with 69 passing and 1 intended failure before the fixes; the final run
  passed all 70.
- Coverage: `npm.cmd run test:coverage` ran 70 tests with all 70 passing and
  reported 92.45% lines, 89.87% branches, and 100% functions for the executable
  JavaScript suite.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| Tracked goals lead current, convertible, other-character, and untracked completed goals; search preserves those groups before fuzzy score | `F3 tracking mode ranks tracked, current, convertible, other, and completed goals` | contract | PASS |
| Arrow presses move once, then repeat after 300 ms every 90 ms while list boundaries remain clamped | `F3 navigation repeats held arrows after a real-time delay without wrapping` | contract | PASS |
| Mouse hover targets only visible tiles, a left-button edge toggles once, and panel shooting suppression is limited to controller 0 | `F3 mouse hover selects visible tiles and a left-click edge toggles tracking` | contract | PASS |
| Real-time arrow and Space menu input cannot also shoot or use an item; nonzero controllers and non-player queries remain untouched | `F3 consumes only controller-zero gameplay actions owned by menu keys` | contract | PASS |
| Existing import, pause, search, character relevance, HUD, and tracking contracts remain intact | complete `npm.cmd test` suite | regression | PASS |

The Node suite validates source contracts but cannot execute the Lua menu inside
Isaac. Live-game checks remain for paused and real-time menus, multiple internal
resolutions, held-key cadence, click-to-track reordering, and multiplayer input
isolation. No checkpoint commits were created because the approved plan requires
review before any commit.

## 2026-08-19 stable untracking order

The approved interaction change keeps an achievement at its current list
position when tracking is removed. Its tracking marker and persisted state
update immediately, while any later list rebuild restores the current priority
order. Newly tracked achievements still refresh immediately and move into the
tracked group.

- RED: `npm.cmd test` ran 78 tests with 77 passing and 1 intended failure for
  the unconditional `toggleGoal` refresh.
- GREEN: after separating the track and untrack refresh paths, the same 78 tests
  all passed.
- Coverage: `npm.cmd run test:coverage` passed all 78 tests and reported 92.45%
  lines, 89.87% branches, and 100% functions for the executable JavaScript suite.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| Untracking saves immediately without rebuilding the list; tracking still refreshes and both keyboard and mouse use the same path | `F3 untracking keeps the current list position until the next refresh` | contract | PASS |
| Reopening F3, search changes, Tab filtering, relevance/completion changes, or another successful track may rebuild the list normally | complete F3 contract suite | regression | PASS |

Live-game confirmation remains for keyboard and mouse untracking on both paused
and real-time F3 menus. No checkpoint commits were created because the approved
plan requires review before any commit.

## 2026-08-22 semantic reward filters

The former catch-all Other filter is split into a single Tab cycle covering All,
Items, Trinkets, Cards, Characters, Monsters, Locations, Challenges, Pickups,
Machines & Scenery, Features, and the residual Other group. The active category
is rendered as one compact localized label with its position in the cycle.

- RED: the focused contract run executed 6 relevant tests with 5 intended
  failures for the missing kind, filter map, metadata overrides, and compact UI.
- GREEN: the same focused run passed all 6 tests after the implementation.
- Search-alias review RED/GREEN: the focused filter contract first failed on
  missing localized category aliases, then passed after all twelve category
  names were made searchable in English and Chinese.
- Regression: `npm.cmd test` passed all 91 tests.
- Coverage: `npm.cmd run test:coverage` passed all 91 tests and reported 94.77%
  lines, 82.61% branches, and 90.32% functions.
- Catalog audit: all 641 achievements resolve to exactly one concrete filter;
  33 playable characters are in Characters while co-player babies remain Other.

| Guarantee | Test | Type | Result |
|---|---|---|---|
| Tab cycles the twelve filters while search still composes with the active filter | `F3 exposes every semantic reward group as a single-level filter` | contract | PASS |
| Boss observations and audited non-standard rewards resolve to monster, location, challenge, pickup, or feature metadata without condition-text guessing | `non-standard achievement rewards use explicit semantic metadata` | contract | PASS |
| All 641 achievements enter exactly one concrete group, including every representative ID in the approved plan | `all 641 achievements have one audited filter including representative rewards` | catalog audit | PASS |
| Pickups have their own filter while machines and grid entities share Machines & Scenery | `F3 maps achievement-unlocked world entities to semantic reward metadata` | contract | PASS |
| New Chinese labels are present in the regenerated bundled font | `bundled LanaPixel assets are complete` | resource | PASS |
| Existing search, tracking, icon, pause, import, and HUD behavior remains intact | complete `npm.cmd test` suite | regression | PASS |

The repository already contained uncommitted F3 untracking changes, so no TDD
checkpoint commits were created. Live-game confirmation remains for both
languages, narrow internal resolutions, empty filters, and the full Tab cycle.
