# Scol Live: the Gemini Live version of the app

`android/` holds the native Android app (Kotlin, Jetpack Compose) first built in Google AI Studio
(repository `Amaljith75/Scol-by-google-`). It teaches the same lessons as the Flutter app in `app/`, and adds:

- **Live tutoring** with Gemini Live: the child talks, the tutor talks back in real time, and it can see the lesson
  board (or the camera) while it explains. There is an end button to stop the live session.
- **A Gemini voice for each character** instead of the Edge voices.
- The tutor brain calls Gemini directly; without a key it falls back to the Scol brain server (`supabase/functions/brain`).

It installs as a separate app (`com.scolapp.live`), next to the older Scol app, so nothing on the phone is lost.

## Building and releasing

The workflow **Build Scol Live (Gemini)** (`.github/workflows/live-app.yml`) runs when `android/` or the lessons change:

1. It rebuilds the lesson bundle from `content/` and copies it into the app.
2. It writes the Gemini key from the first repository secret it finds, in this order:
   `GEMINI_LIVE_API_KEY`, `GEMINI_LIVE_KEY`, `GEMINI_LIVE`, `LIVE_API_KEY`, `GEMINI_KEY`, `GEMINI_API_KEY`.
   The log says which name it used and which Live models that key can reach, never the key.
3. It builds the APK, signed with `android/scol-test.keystore`, so each new build installs over the last.
4. It puts the APK in a **draft** release named "Scol Live ... (Gemini Live)".

Change `versionCode` and `versionName` in `android/app/build.gradle.kts` for a new numbered release.

## Read this before publishing: the key is inside the app

This app sends requests to Gemini with your key from the phone, so the key is built into the APK. Anyone who
downloads the APK can extract it and use your Gemini quota or billing. That is why the release starts as a draft:
you can download and test it while signed in to GitHub, and nobody else sees it.

Before you publish it for families:

- In Google AI Studio or Cloud Console, give this key a **spending limit / quota** you are comfortable losing.
- Better: move to **ephemeral tokens**. The Scol brain server holds the real key and gives the app a short-lived
  token for each live session (Gemini's `auth_tokens` API), so the APK carries no key. Ask for this change when ready.
- `android/scol-test.keystore` (password `scoltest`) is a test signing key kept in this public repository. Before a
  real launch, sign with a private key kept in repository secrets.
