# PURE Desk — expression videos

Drop the face videos in this folder and name them in `faces.json`.

- `default` plays whenever no behaviour is running (the state-driven idle).
- `behaviors.<name>` plays while that behaviour runs; an empty string falls back to `default`.
- Paths are relative to this folder. Videos loop, play muted, and are fitted to the
  108 × 64.8 mm (5 : 3) display with *cover* — a 16 : 9 video loses a little on the left
  and right edges, so keep the face inside the centre 5 : 3 area.
- Use H.264 `.mp4` (or `.webm`). Keep files small (a few MB each) — they are served as
  static files with the site.

Behaviour names: idle, doze, sleep, wake, nod, shake, look_around, curious, happy, sad,
alert, greet, sweep, focus, home.
