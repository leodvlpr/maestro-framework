# Test strategy

> Initial version; regression scope and risk analysis are expanded in Phase 5.

## Suites

| Suite      | Tag          | Purpose                                     | Trigger (planned)          |
| ---------- | ------------ | ------------------------------------------- | -------------------------- |
| Smoke      | `smoke`      | Critical journeys; fast PR gate             | Every PR once CI exists    |
| Regression | `regression` | Broader journeys, happy paths and variants  | Scheduled / pre-release    |

Tests are organized **by business domain** (`.maestro/tests/<domain>/`); the
suite is selected with tags, not folders.

## Inventory

| Test                                           | Domain       | Tags                                    | Data                 | Platform |
| ---------------------------------------------- | ------------ | --------------------------------------- | -------------------- | -------- |
| `onboarding/launch_app.yaml`                   | onboarding   | smoke, critical, onboarding, ios        | —                    | iOS      |
| `onboarding/complete_onboarding.yaml`          | onboarding   | regression, onboarding, ios             | —                    | iOS      |
| `search/open_article.yaml`                     | search       | smoke, critical, search, ios            | `articles.apollo11`  | iOS      |
| `reading_list/save_article.yaml`               | reading_list | smoke, critical, reading_list, ios      | `articles.apollo11`  | iOS      |
| `history/article_in_history.yaml`              | history      | regression, history, ios                | `articles.apollo11`  | iOS      |

All five pass on iPhone 17 / iOS 26.5 with Maestro 2.11.0 (full suite ≈ 3.5 min).
Android is not verified.

## Isolation and data

- Every test starts with `common/launch_clean.yaml` (`clearState`), verified to
  reset onboarding, saved articles and history. Tests never call other tests and
  can run alone or in any order.
- Test data lives in `.maestro/data/` (non-secret). Articles come from live
  Wikipedia: use long-lived articles and never assert on result ranking.
- Created data (saved articles, history) is local to the app and removed by the
  next `clearState`; nothing is created server-side.

## Flake policy

- No automatic retries; no fixed sleeps. Waits are state-based
  (`extendedWaitUntil`, conditional `runFlow`).
- First-run overlays are handled where they appear (see `selector-policy.md`
  and `troubleshooting.md`). A new overlay is a contract change: add it to
  `sut-contract.md` and to the relevant selectors/actions.
