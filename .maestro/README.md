# Maestro workspace

Framework-specific quick start. The SUT and its verified identifiers are in
[`../docs/sut-contract.md`](../docs/sut-contract.md).

## Layout

```text
.maestro/
├── config.yaml              # Discovery + default output dir
├── flows/
│   ├── smoke/               # PR-critical journeys (discovered)
│   ├── regression/          # Broader journeys (discovered)
│   ├── platform/{android,ios}/   # Platform-only journeys (discovered)
│   ├── components/          # Reusable subflows (NOT discovered)
│   │   ├── app/ navigation/ permissions/ assertions/
│   │   └── platform/{android,ios}/   # Platform adapter subflows
│   └── support/             # Non-executable helpers (NOT discovered)
├── scripts/js/              # Small runScript helpers
└── data/{fixtures,schemas}/ # Synthetic, non-secret data
```

Discovery was proven on Maestro 2.11.0: with tagged probe flows placed in
`components/` and `support/`, a workspace run executed only `flows/smoke/`.

## Run

Run from the **repository root** — Maestro resolves `testOutputDir` and
`--test-output-dir` against the current working directory.

```bash
maestro --device <device-id> test \
  -e APP_ID=org.wikimedia.wikipedia \
  -e TARGET_PLATFORM=ios \
  -e RUN_ENV=sample \
  -e RUN_ID=local-001 \
  --test-output-dir artifacts/maestro/local-001 \
  --include-tags=smoke \
  .maestro
```

Use the app ID verified for the target platform in the SUT contract. Without
`--test-output-dir`, output goes to `artifacts/maestro/default/` (ignored).

## Runtime variables

| Variable          | Source                     | Secret? | Purpose                                     |
| ----------------- | -------------------------- | ------- | ------------------------------------------- |
| `APP_ID`          | Local command or CI matrix | No      | iOS bundle ID / Android package (required)  |
| `TARGET_PLATFORM` | Local command or CI matrix | No      | `android` / `ios`, for known platform logic |
| `RUN_ENV`         | Local command or CI matrix | No      | `sample`, later `staging`                   |
| `RUN_ID`          | CI run ID or chosen locally| No      | Namespaces test data and artifacts          |

Secrets (none needed yet) must come from the shell/CI as `MAESTRO_*`
variables, never from YAML, JS or fixtures. See `../.env.example`.

## Conventions

- Executable flows start with `appId: ${APP_ID}`, a descriptive `name`, and
  tags (`smoke`/`regression` plus risk and platform tags). Never hard-code an app ID.
- File names are lowercase `verb_noun.yaml`; one file = one independent journey.
- State preconditions in a comment at the top of each flow.
- Components live under `flows/components/`, take explicit `env` inputs and
  carry no suite tags; call them with `runFlow: {file: ..., label: ...}`.
- Tag `cross-platform` only after the same journey has passed on Android and iOS.

## Components

| Component                                    | Responsibility                                          | Inputs                                |
| -------------------------------------------- | ------------------------------------------------------- | ------------------------------------- |
| `components/app/launch_clean.yaml`           | `clearState` launch, skip onboarding, land on home      | —                                     |
| `components/app/dismiss_tips.yaml`           | Dismiss any visible first-run tip/prompt (idempotent)   | —                                     |
| `components/navigation/open_article_from_search.yaml` | Search, open the result, wait for article content | `SEARCH_QUERY`, `ARTICLE_DESCRIPTION` |
| `components/assertions/assert_article_saved.yaml` | Verify the article is listed in Saved              | `ARTICLE_TITLE`, `ARTICLE_DESCRIPTION` |

No permissions component exists: no permission dialog was observed in the
covered journeys. Journey test data lives in each flow's `env:` header; no
JavaScript helper or fixture file is needed because the sample creates no
uniquely named data (saved articles are local and reset by `clearState`).

`open_article_from_search` waits up to 10 s / 20 s for first-run tips with
`optional: true`. On a clean install (every journey uses `launch_clean`) the
tips always appear, so the waits end early; reuse within the same app session
pays the full timeout.

## Notes

- `platform.*.disableAnimations` in `config.yaml` is a Maestro Cloud-only
  setting, so it is intentionally not configured for local runs.
- Maestro MCP and the CLI each drive the device through the XCTest runner. After
  a CLI run, an already-connected MCP session can fail with
  `Device became unreachable`; reconnect the MCP server (`/mcp` in Claude Code).
