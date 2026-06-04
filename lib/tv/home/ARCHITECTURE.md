# LiveGO TV Home Architecture Lock

This folder is intentionally split so Home does not become a dumping ground again.

## Rules

1. `tv_home_screen.dart`
   - Layout only.
   - Remote event passing only.
   - It may call provider/focus methods, but must not own API/network policy.
   - It must not own provider fallback policy.
   - It must not own image/cache policy.

2. `providers/tv_home_provider.dart`
   - Owns Home data state.
   - Owns loading/refreshing/error/fromCache state.
   - Owns retry for the last Home request.
   - Talks to `LiveGoCatalog`, not raw endpoint clients.

3. `focus/tv_home_focus_state.dart`
   - Owns focus memory only:
     zone, platform index, category index, grid index.
   - It must not fetch API data.
   - It must not decide Home content.

4. `lib/tv/widgets/*`
   - Reusable TV widgets only.
   - Should receive data/callbacks from parent.
   - Should not directly call provider/network unless the widget is explicitly a provider-bound widget.

## Back and focus rule

One remote key must produce one action.
Focus moves first, scroll follows, image loading happens later.

## Shell keep-alive rule

`TvLazyIndexedStack` must not keep every screen alive by default.

Current rule:
- Home stays alive.
- Secondary screens are disposed when inactive unless testing proves otherwise.

Reason:
Low-end Android TV boxes can become slow if Search, Library, Download, Account,
and Home all stay mounted with images/lists/focus nodes.

Potential future adjustment after real device testing:
- Add Search to keepAlive if keyboard/search rebuild feels slow.
- Add Account to keepAlive only if account menu restore feels rough.

## Home interaction controller split

`tv_home_screen.dart` should stay thin.

Current rule:
- `tv_home_screen.dart` owns widget layout, FocusNode fields, ScrollController, init/dispose, and build wiring.
- `tv_home_interaction_controller.dart` owns focus movement, BACK ladder, key handlers, retry focus, restore-zone logic, and platform/category/grid interaction.
- This file is a `part` of `tv_home_screen.dart` so it can safely access private focus nodes and context without turning Home into a fragile dependency graph.

Do not move FocusNode ownership out of the screen until real-device tests prove the split is stable.

## Boundary guardrails

Detailed current Home boundary rules live in `BOUNDARY.md`.
