# F3 Multi-Route Selection: TDD Evidence

## Scope

This change implements the user-approved F3 multi-route selection plan:

- List every compatible route that still has unfinished goals.
- Rank routes by four recommendation tiers, total goals, catalog order, and fixed route order.
- Keep the tracked route first, reachable routes next, and unavailable routes disabled at the bottom.
- Allow an available route to replace the tracked route without consuming another tracker slot.
- Remember route-aid items seen anywhere on the current floor, including R Key, without changing the save schema.

## User Journeys

1. A player opens F3 and sees all normal-mode or greed-mode routes that still contain relevant unfinished goals.
2. A player inspects a route and sees its available members, missed members, recommendation composition, and first failure reason.
3. A player switches from one selectable route to another while the tracker is full; the route still occupies one slot.
4. A player cannot select a gray unavailable route and receives a short explanation.
5. A route-aid item seen earlier on the current floor remains available to route evaluation until the floor changes.
6. A seen or held R Key makes unfinished normal-mode routes recoverable, while an invalid character or globally locked entrance remains invalid.

## RED

- `e7ff1ab test: specify F3 multi-route selection`
  - New contract suite result before implementation: 0 passed, 5 failed.
- `ebcfabe test: align route scoring with multi-route selection`
  - Updated route-scoring contract result before implementation: 8 passed, 6 failed.

The failures covered missing route enumeration/status, merged scoring, manual discouraged goals, floor aid persistence, R Key recovery, route replacement, and F3 route-only rows/details.

## GREEN

- Focused route suites: 14 passed, 0 failed.
- Complete test suite: 172 passed, 0 failed.
- Coverage:
  - Lines: 95.02%
  - Branches: 84.41%
  - Functions: 90.63%
- Font-character and 320x180 pagination checks are included in the complete suite and passed.

## Remaining Manual Check

The automated environment does not include the game's Lua runtime. In-game smoke testing should verify opening F3, switching routes with a full tracker, selecting a disabled route, retaining an aid after leaving its room, and clearing floor aids on the next floor or after a route reset.
