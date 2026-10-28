# Mac v2 verification — 2026-10-28

| Check | Result |
| --- | --- |
| Unit tests (`ClipBarTests`) | 70 passed |
| `ClipBar --selftest` (QR generate + scan, OCR, data URL, background removal, templates, calculator) | all passed |
| Existing history migrated to the new schema | yes, clips kept, Library tables created |
| Capture while running from /Applications | yes, with source app |
| Panel position (`--open-panel`, window list) | 480×620 directly under the status item |
| Independent code review | 8 issues found, all fixed |

Panel renders for 15 scenarios are in `mac/` (rendered offscreen, so the Liquid Glass
material itself is not visible there; a gradient stands in for the desktop).

Not verified by automation: clicking through the live panel, the global hotkey, pasting into
another app (needs Accessibility permission), Contacts access (needs permission).
