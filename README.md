# Recall

A Flutter flashcard app for building and reviewing vocabulary decks.

## Features

- Create, rename, and manage vocabulary decks.
- Add, edit, bookmark, delete, or exclude individual cards from review.
- Import cards from CSV files with English or Korean headers for word, meaning, and example.
- Attach an image to a card and reveal its example only after flipping the card.
- Set a daily study goal in Settings.
- Decks, cards, bookmarks, review exclusions, and the daily goal are stored locally.

CSV files can use `front,meaning,example` or `단어,뜻,예문` as their header row.

## Run

Install the Flutter SDK and Chrome, then run from the project directory:

```sh
flutter pub get
flutter run -d chrome
```

On Windows, if Flutter's shader compiler crashes, keep both the project and the
Flutter SDK in paths that contain only ASCII characters. The review page opens
from **Start Review** on the home screen.

To target Android, install the Android SDK and select a connected device or
emulator before running `flutter run`.

The app uses Flutter's Material widgets and `shared_preferences` for local
storage.
