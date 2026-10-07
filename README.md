# Recall

A Flutter vocabulary review dashboard based on the supplied Lexicon home-screen design.

## Features

- Create decks and add, view, or edit cards with an original, meaning, and example.
- Review due cards with Again, Hard, Good, and Easy scheduling.
- Set a daily study goal in Settings; today's remaining count updates from due cards.
- Decks, cards, review schedules, and the daily goal are stored locally.

The Import CSV action is a placeholder; CSV file selection and parsing are not
implemented yet.

## Run

Install the Flutter SDK and Chrome. On Windows, if your project or Flutter SDK
path contains Korean or other non-ASCII characters, map both to ASCII drive
letters before running Flutter:

```powershell
subst R: "$env:USERPROFILE\OneDrive\Desktop\Recall"
subst S: "$env:USERPROFILE\flutter"
Set-Location R:\
S:\bin\flutter.bat pub get
S:\bin\flutter.bat run -d chrome
```

The drive mappings last for the current Windows sign-in session. If a drive
letter is already mapped, inspect `subst` and use the existing mapping instead
of mapping it again. The review page opens from **Start Review** on the home
screen.

To target Android, install the Android SDK, then run the same Flutter command
with an Android device or emulator selected. `flutter doctor` currently reports
that the Android SDK is not installed.

The app uses Flutter's Material widgets and `shared_preferences` for local
storage.
