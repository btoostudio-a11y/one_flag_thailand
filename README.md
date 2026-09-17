# ONE FLAG THAILAND — Falling Tap Game

A mobile-first Godot 4 prototype using the supplied artwork. The playable loop is start, countdown, 25-second fall, landing, results, replay, and server-backed scores.

## Run

Open `project.godot` in Godot 4.x and press **F5**. The entry point is `res://scenes/Main.tscn`. Mouse clicks work on desktop; `Area2D.input_event` also handles `InputEventScreenTouch` on phones.

## Tuning

All first-pass balance values are in `res://data/game_config.gd`:

- `SPEED_STEPS`: movement speed and spawn interval for each time band.
- `EARLY_WEIGHTS`, `MID_WEIGHTS`, `LATE_WEIGHTS`: editable Thai/USA/UAE/bomb percentages.
- `BASE_SCORE`, `BOMB_PENALTY`, and `MAX_MULTIPLIER`: scoring.
- `GAME_DURATION` and `START_ALTITUDE`: run length/progress.

## Art replacement

The included source sheets are already wired through atlas regions. Optional standalone PNGs take priority automatically:

- `assets/characters/character_fall.png`
- `assets/flags/thai_flag.png`, `usa_flag.png`, `uae_flag.png`
- `assets/obstacles/bomb.png`
- `assets/backgrounds/bg_game_long.png` is the active non-looping gameplay background. Other background names remain available for future phases.
- `assets/ui/logo_one_flag_thailand.png`

If an optional gameplay image is missing, the code uses the supplied sheet and finally a drawn fallback. Backgrounds and logo also check before loading.

Drop optional OGG audio into `assets/audio/` using: `tap_correct.ogg`, `tap_wrong.ogg`, `bomb.ogg`, `combo.ogg`, `countdown.ogg`, `game_start.ogg`, and `game_finish.ogg`. Missing audio is silently skipped.

## Structure

- `scenes/`: screen scenes and entry point.
- `objects/`: reusable Thai, USA, UAE, bomb, and player scenes.
- `scripts/`: routing, gameplay, spawner, score, backgrounds, leaderboard, audio, and UI helpers.
- `data/`: balance config and mock leaderboard JSON.
- `ui/`: reusable HUD/pause scene stubs for editor expansion.
- `tests/`: headless end-to-end smoke test.

`LeaderboardManager.get_entries()` reads the verified account top-10 from the game API.
No mock rows are displayed as real rankings.

## Guest scores and optional login

The standalone game saves Guest rounds before login. Server-generated objects and
server receive times determine the stored score. Players can optionally create an
email-confirmed account and log in to claim their previous Guest rounds.

**Run the prepared Web build:**

```powershell
python tools/serve.py
```

Open http://localhost:8060 and play a full round. The result displays
**SAVED TO DATABASE** and a Round ID to inspect in Supabase `standalone_rounds`.
This is a Godot project; no `npm run dev` or website server is needed.

See [testing, building and account setup](docs/testing.md) for full instructions.
The gameplay API is deployed as the `standalone-game` Supabase Edge Function.
The presentation website is not required and its UI was not changed for this work.
