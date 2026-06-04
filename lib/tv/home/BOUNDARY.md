# LiveGO TV Home Boundary Guardrails

This is the active Home architecture standard.

## File responsibilities

### `tv_home_screen.dart`
Owns:
- widget layout
- FocusNode lifecycle
- ScrollController lifecycle
- initState / didUpdateWidget / dispose
- callback wiring from widgets to the interaction layer

Must not own:
- API endpoint logic
- cache/fallback policy
- raw provider parsing
- long key-handler logic
- BACK ladder logic

### `tv_home_interaction_controller.dart`
Owns:
- DPAD / OK / BACK handlers
- focus movement
- BACK ladder
- retry focus recovery
- restore-zone decision
- platform/category/grid index movement
- detail route restore callback

May access:
- `tv_home_provider.dart` for load/retry only
- `tv_home_focus_state.dart` for focus/index memory
- FocusNodes through the screen part-extension while this split remains stable

Must not own:
- API endpoint clients
- image/cache policy
- heavy UI layout
- player logic

### `focus/tv_home_focus_state.dart`
Owns:
- zone memory
- platform/category/grid index memory

Must not own:
- FocusNode lifecycle
- network/data fetching
- widget layout

### `providers/tv_home_provider.dart`
Owns:
- Home data
- loading / refreshing / error / fromCache
- retry
- cache-first Home loading through `LiveGoCatalog`

Must not own:
- FocusNode
- TV key handling
- widget layout

## Current implementation choice

`tv_home_interaction_controller.dart` is currently a Dart `part` extension.

Reason:
TV focus logic still needs safe access to private FocusNodes, `mounted`, `context`,
`ref`, and `setState`. A separate ChangeNotifier class can come later only after
real Android TV testing proves focus restore is stable.

## Rule for future patches

Do not add new focus/key/back methods to `tv_home_screen.dart`.
Put them in `tv_home_interaction_controller.dart`.
