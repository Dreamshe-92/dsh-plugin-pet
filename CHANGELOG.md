# Changelog

## 0.2.0 — 2026-08-31

- Codex pet contract support: 1536x1872 / 8x9 / 192x208 atlases are detected
  and played back with the official per-row animation semantics and frame
  durations (idle / running / waiting / jumping / waving / running-left/right).
- Bottom-edge wandering: the pet strolls along the window floor between
  random pauses, using the direction rows. Double-click toggles freeze/wander
  (persisted in localStorage).
- New-reply notify: red badge + bubble + jumping row for ~60s after an agent
  turn finishes; click to acknowledge.
- Drag-to-place anywhere in the window.
- Reduced-motion support: static idle frame 0.
- Pet switching with automatic grid measurement (alpha-channel scan) for
  non-contract sheets; manual --cols/--rows override.
- pet.json displayName feeds tooltips.
- Build pipeline: shared tools/build_client.js with syntax + runtime CSS
  gates; install.sh / uninstall.sh / switch_pet.sh.

## 0.1.0 — 2026-08-21

- Initial release: sidebar-footer pet avatar, session state machine
  (sleep/idle/working/waiting), sprite playback, install into both DSH
  profiles with YAML-safe patching.
