# Standalone game: play, save, then sign in

## Quick test (no npm, no website server)

From this repository:

```powershell
python tools/serve.py
```

Open http://localhost:8060, press **TAP TO START**, and play for 25 seconds.
The result should show **SAVED TO DATABASE**, the verified score and a short Round ID.
The first request can take longer while the backend starts.
The generated Web build is in `build/web`.

To verify storage, Supabase Table Editor -> `standalone_rounds`:
match the Round ID prefix, check `score` and non-empty `finished_at`.
A Guest has `user_id = NULL`. Do not disclose `token_hash` or device receipt tokens.

## Optional account

On the result screen choose **ACCOUNT / LINK MY SCORES**:
enter nickname, email and password, create account, confirm using the email,
then return to the game and press **LOGIN**. Existing verified accounts can log in directly.
Saved guest rounds are linked after login; the same database row now has a user_id.
The leaderboard shows one best round per account. An account cannot claim an already
claimed round owned by someone else. Sign out is available from the account screen.

Supabase SMTP must permit the recipient for confirmation email to arrive. Default test
mail may only allow project-team recipients. Email confirmation is intentionally not bypassed.
No Google OAuth setup is required for this build. Verification emails use the project's
existing redirect setting; after confirming, return to this game and log in.

Guest receipts remain on the same browser/device (up to 100 recent rounds).
Clear site data / use private browsing / change game origin and those unclaimed
receipts may be lost. A guest round can be claimed within 30 days.
Public rankings exclude unclaimed Guest rounds; the score itself is already in the database.

## Build

Godot 4.7 is required. The upstream non-threaded engine is pinned in `build/web.zip`.
Rebuild the PCK and update its shell size:

```powershell
powershell -ExecutionPolicy Bypass -File tools/build-web.ps1 -Godot "C:\path\Godot_v4.7-stable_win64_console.exe"
python tools/serve.py
```

Alternatively open `project.godot` in Godot 4.7 and press F5 for native play.
This is a Godot project, so `npm run dev` is not applicable.
To update itch.io, upload the generated standalone web ZIP as an HTML game.
The existing public itch.io game is unchanged until that upload is performed.

## Backend and credentials

`supabase/functions/standalone-game/index.ts` is the standalone Edge API.
`data/supabase_config.gd` contains only project URL and the browser-safe publishable key.
Never place the service-role/secret key in Godot, Web exports or Git.

Migration `20260916093954_standalone_guest_game.sql` introduces isolated standalone
tables without changing the main website's game tables. Do not run the retired
`supabase/schema.sql` leaderboard prototype. On this shared project, avoid a blanket
`db push`: website migrations have a separate history. Apply only reviewed pending migrations.

```powershell
npx.cmd supabase functions deploy standalone-game --project-ref liglyabxnhugdsqobtql --no-verify-jwt --use-api --agent no
```

JWT verification is disabled at the gateway because Guest actions need no login.
The claim action independently checks the user's Auth token and confirmed email.
Every round is controlled by a 256-bit random capability, stored hashed in the database.
Browser roles have no direct table/RPC access. The API never accepts a score field.
Server receive time, spawn plan, unique hits and scoring rules determine the stored score.
Requests retry safely; completed scores cannot be edited.

This validates legal gameplay actions, not whether a human played. A modified client
can automate valid hits. The hourly begin limit is a basic abuse control, not bot detection.
Network latency can reject late taps, so the final server score can differ from the HUD.
Connection failure is shown explicitly; offline practice never uploads claimed scores.

## Automated checks

```powershell
$env:ONEFLAG_OFFLINE="1"
godot --headless --path . res://tests/SmokeTest.tscn
godot --headless --path . res://tests/SaveFlow.tscn
Remove-Item Env:ONEFLAG_OFFLINE
npx.cmd supabase db query --linked --project-ref liglyabxnhugdsqobtql --file supabase/tests/standalone.sql --agent no
```

API integration uses a server-side test secret in a private local .env file (not shipped).
It creates and removes disposable test accounts/rounds, with no email sent:

```powershell
node --env-file=.env.test tests/api-integration.mjs
```

Set GODOT_BIN to the engine executable to additionally test a real Godot round and
Godot account login/claim. SQL fixtures roll back; the integration runner cleans its rows.
The standalone LiveGuest.tscn test by itself leaves one Guest result for inspection.

Checks completed: offline smoke, real native Godot guest play, Edge/API round, database
persistence, replay rejection/idempotency, account claim and SQL ownership/privileges.
WebGL visuals and actual confirmation email delivery still require manual browser testing.
Security Advisor currently reports leaked-password protection disabled in shared Auth;
no table/function security warning was reported. Enable the Auth feature when supported.

Save-flow regression tests cover immediate navigation locking during retry, successful/failed
save completion, last-round retention after claim, and malformed local receipt tokens.
The build script refreshes both the Web PCK and standalone-web.zip together.
