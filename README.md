# Subscription Tracking App

SubGlass is a local-first subscription tracker built with Flutter, Riverpod, and
SQLite (Drift). PHP is the default display currency; subscription amounts keep
their original currency.

## Features

- Subscription CRUD, custom cycles, categories, cropped local logos, auto-renew
  date rollover, and renewal reminders.
- Payment-method tags and filters.
- Monthly and yearly spend summaries, a configurable monthly budget, and an
  interactive category chart.
- Cached live exchange rates, offline calculations, and per-currency manual
  PHP exchange-rate overrides.
- CSV export and ZIP backup/restore with subscription images.
- Responsive mobile dashboard and tablet/desktop navigation layout.

- <img width="930" height="695" alt="image" src="https://github.com/user-attachments/assets/45f1e404-bab2-4774-a064-7d6348c1e267" />
- <img width="916" height="690" alt="image" src="https://github.com/user-attachments/assets/20743455-49e5-4463-ba0c-202c2ff34a52" />



## Run

Install Flutter with Dart 3.8 or later (Flutter 3.32+), then:

```sh
flutter pub get
flutter run
```

Run checks with `flutter analyze` and `flutter test`. Drift web builds also need
`web/sqlite3.wasm` and `web/drift_worker.js`, which are included in this project.

## Platform notes

- Android scheduled reminders require notification and exact-alarm permission.
  Android may deliver inexact reminders if exact-alarm access is denied.
- The underlying notification plugin does not schedule notifications on Linux
  and does not support Windows; web notifications are not configured.
- The browser stores small custom icons locally with app preferences; native
  builds store icons in the application documents directory.
