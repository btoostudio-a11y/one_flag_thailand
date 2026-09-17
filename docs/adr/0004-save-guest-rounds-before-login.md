# Save guest rounds before optional account login

Status: accepted, 2026-09-16. Supersedes ADR-0002; email/password confirmation replaces
the Google-only implementation described in ADR-0001 for this development build.

The owner explicitly requested play without login, save score, then optionally verify
identity and log in. The standalone game therefore saves server-calculated guest rounds
and retains a random capability on the player's device; a verified account can claim
those existing rounds later. Only claimed rounds enter public rankings, keeping the
best individual score rather than summing guest rounds.

Account signup uses Supabase email confirmation and password login inside Godot, so
testing needs no Google OAuth application or main-site UI. Email delivery remains
dependent on the project's SMTP configuration. The game has its own Edge Function;
no runtime dependency on the presentation website is required.
