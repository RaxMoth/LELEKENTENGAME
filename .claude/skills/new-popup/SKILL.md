---
name: new-popup
description: Scaffold a new popup (dialog) scene that extends BasePopup and follows the design system.
argument-hint: "[PopupName] [what it shows]"
disable-model-invocation: true
---
Create `Scenes/UI/Popups/$0/$0.tscn` and its script by copying the structure
of `Scenes/UI/Popups/ConfirmPopup/` (root `Control` with `extends BasePopup`,
`%Backdrop` ColorRect, `CenterContainer/%Panel` PanelContainer).

- Override `_on_opened(data: Dictionary)`; finish with `close(result)`.
  Implement `handle_back()` if back should do something other than close.
- Title `HeaderLabel`, body `Label`/`SmallLabel`, exactly one primary
  `Button`; other actions `SecondaryButton` or `GhostButton`.
- Amounts with `IconLabel` / `RewardList`, never text glyphs.
- Open it with `await UI.open_popup(PRELOADED_SCENE, {...}).closed`.
- Add it to `Tests/smoke_test.gd`'s popup checks, run the `smoke-test` skill,
  then check it with the `design-review` skill (`popup=res://...`).
