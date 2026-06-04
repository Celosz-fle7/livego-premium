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
