# SUT contract — Wikipedia sample app (Maestro samples)

This contract is the adapter boundary between the framework and the system
under test (SUT). Everything below was observed on a real target unless it is
explicitly marked **not verified** or **not available**. Flows must not rely on
anything that is not listed here.

Last verified: 2026-10-02.

## SUT name and source

| Field             | Value                                                                                       |
| ----------------- | ------------------------------------------------------------------------------------------- |
| SUT               | Wikipedia (official Wikimedia app), as bundled by `maestro download-samples`                |
| Source command    | `maestro download-samples -o work/maestro-samples` (Maestro CLI **2.11.0**)                 |
| iOS build         | `Wikipedia.app` 7.8.8 (`CFBundleVersion` 0), simulator-only, arm64 + x86_64, min iOS 16.6   |
| iOS build SDK     | `iphonesimulator26.0`                                                                       |
| Archive checksums | `wikipedia.zip` SHA-256 `8ee09a8e88e69b7495f8e065eb748c3e3e3250ad47f21a5697305e1aa6ce93cd`  |
|                   | `wikipedia.apk` SHA-256 `eba82a0f77940d8a6be5bd2e53723675a59859a6c8a51be5e50bd034fc77101f`  |

`sample.zip`/`sample.apk` in the download are byte-identical copies of
`wikipedia.zip`/`wikipedia.apk`.

## Binary handling

- Acquired at runtime with `maestro download-samples` into `work/maestro-samples/`
  (ignored by Git). Binaries are never committed.
- iOS install (simulator must be booted):

  ```bash
  unzip -q -o work/maestro-samples/samples/wikipedia.zip -d work/maestro-samples/ios -x '__MACOSX/*'
  xcrun simctl install <simulator-udid> work/maestro-samples/ios/Wikipedia.app
  ```

- Android: `work/maestro-samples/samples/wikipedia.apk` would be installed with
  `adb install`; **not verified** (no Android target available yet).

## App identifiers

| Platform | App ID                    | Status                                                                                        |
| -------- | ------------------------- | --------------------------------------------------------------------------------------------- |
| iOS      | `org.wikimedia.wikipedia` | **Verified** — `Info.plist` and `xcrun simctl listapps` on the installed simulator app       |
| Android  | `org.wikipedia`           | **Not verified** — taken from the supplied `android-flow.yaml`; confirm on an installed APK |

## Verified target

| Field            | Value                                                        |
| ---------------- | ------------------------------------------------------------ |
| Platform         | iOS Simulator                                                |
| Device / OS      | iPhone 17, iOS 26.5                                          |
| Locale           | `en_US@rg=eszzzz`; preferred languages `en-US, en-ES, es-US` |
| Host             | macOS (arm64), Xcode 27.0                                    |
| Maestro CLI      | 2.11.0 (official release, verified against release checksum) |

## Known-good launch (Phase 1 validation)

Supplied, unmodified sample flow:

```bash
maestro --device <simulator-udid> test \
  --test-output-dir artifacts/maestro/phase1-sample-ios-flow \
  work/maestro-samples/samples/ios-flow.yaml
```

Result: **pass** (`launchApp` on `org.wikimedia.wikipedia`). Output kept under
`artifacts/maestro/phase1-sample-ios-flow/` (ignored).

The supplied `ios-advanced-flow.yaml` **fails** on this build at its final
`assertVisible: "qwerty"`: the first-run "Add languages" tip (see *Interruptions*)
hides the search results from the accessibility tree. Dismissing the tip makes
the assertion pass. This is sample/app drift, not a framework defect; the sample
is left unmodified.

## Supported journeys (observed on iOS)

| Journey              | Business description                                    | Observed steps and outcome                                                                                                                           |
| -------------------- | ------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Launch to home       | A new user reaches the main screen                      | `launchApp` (clearState) → onboarding page 1 → `Skip` → home with the tab bar visible                                                                |
| Complete onboarding  | A new user reads the introduction before starting       | 4 pages: "The free encyclopedia", "New ways to explore", "Search in over 300 languages", "Data & Privacy" → `Get started` → home                      |
| Search and open      | A reader finds an article by keyword and opens it       | Tap `Search Wikipedia` → type query → results list (title + short description) → tap result → article with title and description visible             |
| Save article         | A reader saves an article to read later                 | In article, tap `Save for later` → button becomes `Saved. Activate to unsave.` → Saved tab → "All articles" lists the article                        |
| Reading history      | A reader sees articles opened today                     | History tab → "Today" section lists the opened article; `Clear` button available                                                                     |
| Places (map)         | A reader browses places on a map                        | Places tab opens a map (centred by device region) with `Map`/`List` toggle and `Filter`; no permission prompt on entry. Location button **not tested** |

Not suitable for journeys on this target:

- **Explore feed**: stayed on a loading spinner (blank feed) in two separate
  sessions, although search and article content loaded. Treat as unavailable
  until the cause is understood.

## Stable locators

Preference order follows the selector policy: resource ID → accessibility label/text → regex.

| Element                        | Selector                                         | Type             | Notes                                                                 |
| ------------------------------ | ------------------------------------------------ | ---------------- | --------------------------------------------------------------------- |
| Tab: Explore                   | `id: tabbar-explore`                             | resource ID      |                                                                       |
| Tab: Places                    | `id: tabbar-nearby`                              | resource ID      |                                                                       |
| Tab: Saved                     | `id: tabbar-save`                                | resource ID      |                                                                       |
| Tab: History                   | `id: tabbar-recent`                              | resource ID      |                                                                       |
| Tab: Search                    | `id: search`                                     | resource ID      |                                                                       |
| Profile button                 | `id: profile-button`                             | resource ID      |                                                                       |
| Article back button            | `id: BackButton`                                 | resource ID      | Label is the previous screen name (e.g. "Explore")                    |
| Article toolbar                | `id: Toolbar`                                    | resource ID      |                                                                       |
| Saved scope bar                | `id: scopeBar`                                   | resource ID      | Children: `All articles`, `Reading lists`                             |
| Onboarding: next / skip        | `Next`, `Skip`                                   | label            | Pages 1–3 expose `page N of 4`; the last page has no page indicator   |
| Onboarding: finish             | `Get started`                                    | label            | Only on the last page ("Data & Privacy")                              |
| Search field (home/article)    | `Search Wikipedia`                               | label / hint     | When filled, its text equals the query — avoid tapping results by title text alone |
| Search: clear / close          | `Clear text`, `Close`                            | label            |                                                                       |
| Search: empty state            | `No recent searches yet`                         | text             |                                                                       |
| Search result                  | result description, e.g. `First crewed Moon landing \(1969\)` | text (regex) | Rows have no IDs; title + description are **live Wikipedia data**     |
| Article title container        | `id: <article title>` (e.g. `Apollo 11`)         | resource ID      | Header container ID equals the article title                          |
| Save toggle (unsaved)          | `Save for later`                                 | label            | Reads `save` while the article is still loading                       |
| Save toggle (saved)            | `Saved. Activate to unsave.`                     | label            |                                                                       |
| Saved: empty state             | `No saved pages yet`                             | text             |                                                                       |

## Interruptions (first-run tips and prompts)

Each appears once per fresh install / `clearState` and must be handled
idempotently (conditional, not mandatory). While any of these is visible, the
content behind it is **hidden from the accessibility tree**, so assertions on
that content fail.

| Trigger                       | Text                                   | Dismiss with                        |
| ----------------------------- | -------------------------------------- | ----------------------------------- |
| First search results load     | "Add languages"                        | `tapOn: {id: PopoverDismissRegion}` |
| First article opened          | "Tap to go back" → "Open in new tab"   | `tapOn: "Got it"` (repeat while visible; they chain) |
| After saving an article       | "Add "Apollo 11" to a reading list?" banner | Disappears by itself (≈ a few seconds); wait for `notVisible` |
| First visit to Saved tab      | "Sync your saved articles?" (`id: reading-list-login`) | `tapOn: "Close"`         |
| Sample flows also handle      | "Explore your Wikipedia Year in Review", "You have been logged out" | Not observed on this build/date |

## Known platform differences

- Only iOS has been exercised. Android behaviour, IDs and dialogs are
  **not verified**; the supplied Android flows use different subflows
  (`onboarding-android.yaml`, `launch-clearstate-android.yaml`).
- Onboarding language list and Places map region depend on the device locale
  (`en_US@rg=eszzzz` here: English + Español, map centred on Spain).

## Reset and cleanup

- `launchApp: {clearState: true}` on iOS **was verified** to reset onboarding,
  remove saved articles ("No saved pages yet") and clear History.
- The app is used without a login; no data is created on Wikipedia servers.
  Saved articles and history are local to the app and removed by `clearState`.
- First-run tips reappear after every `clearState` (see *Interruptions*).

## External dependencies and risks

- Search results, article text and descriptions come from live Wikipedia.
  Assertions should target long-lived facts (e.g. the "Apollo 11" article) and
  avoid ranking/position of results.
- Article content can take several seconds to render; use state-based waits.
- Network access is required for search and articles.

## Replacement mapping (sample → real app)

| Sample capability / locator        | Real-app equivalent to define                              |
| ---------------------------------- | ---------------------------------------------------------- |
| `APP_ID` `org.wikimedia.wikipedia` | Real iOS bundle ID / Android package per environment       |
| Onboarding (`Skip`/`Get started`)  | Real first-launch flow (onboarding, consent, login)        |
| First-run tips (Interruptions)     | Real app's coach marks, rating prompts, permission dialogs |
| Search → open article              | Main search / catalogue → detail journey                   |
| Save article / Saved tab           | Create-or-favourite entity → verify in list                |
| History tab                        | Recently viewed / activity list                            |
| Tab bar IDs (`tabbar-*`)           | Real navigation IDs supplied by the app team               |
| `clearState` reset                 | Real reset strategy (clearState, test API, snapshot)       |
