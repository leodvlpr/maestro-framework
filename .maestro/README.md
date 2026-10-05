# Maestro workspace

Page Object Model (POM) for Maestro. The SUT and its verified identifiers are
in [`../docs/sut-contract.md`](../docs/sut-contract.md); the selector rules are
in [`../docs/selector-policy.md`](../docs/selector-policy.md).

## Layout

```text
.maestro/
├── config.yaml                 # Discovery: only tests/** is executed
├── selectors/                  # ALL identifiers, isolated from flows
│   ├── pages/<screen>.js       #   output.<screen> = { id: {...}, text: {...} }
│   └── components/<name>.js    #   output.<component> = { id: {...}, text: {...} }
├── tests/                      # Tests, one folder per business domain
│   ├── onboarding/
│   ├── search/
│   ├── reading_list/
│   └── history/
├── pages/                      # Page Objects: actions/assertions, one folder per screen
│   └── <screen>/<verb_noun>.yaml
├── components/                 # Actions of UI components shared by several screens
│   ├── tab_bar/                #   bottom tab bar
│   └── tips/                   #   first-run tips (overlays)
├── common/                     # App-level hooks (launch_clean)
└── data/                       # Test data (articles.js)
```

| Layer         | Contains                                               | Imports                          | Discovered as test? |
| ------------- | ------------------------------------------------------ | -------------------------------- | ------------------- |
| `selectors/`  | Identifiers only, grouped by type (`id` / `text`)      | —                                | No                  |
| `tests/`      | Business scenarios: compose pages + components + data  | `data/`, `selectors/` if needed  | **Yes**             |
| `pages/`      | Actions and assertions of **one** screen               | `selectors/pages/<screen>.js`    | No                  |
| `components/` | Actions of a widget used on many screens               | `selectors/components/<name>.js` | No                  |
| `common/`     | App lifecycle steps (launch, reset)                    | —                                | No                  |
| `data/`       | Synthetic, non-secret test data                        | —                                | No                  |

### Rules

1. **Every identifier lives in `selectors/`.** No literal `id:`/`text:` value in
   `tests/`, `pages/`, `components/` or `common/`. Dynamic values passed as
   inputs (e.g. an article title from `data/`) are the only exception.
2. **Selector files are grouped by type**: `output.<name>.id.<key>` holds resource
   IDs, `output.<name>.text.<key>` holds visible text / accessibility labels.
3. **Every element access declares its type explicitly** — never the shorthand
   string form:

   ```yaml
   # ✅
   - tapOn:
       id: ${output.article.id.backButton}
   - assertVisible:
       text: ${output.saved.text.allArticlesTab}
   - runFlow:
       when:
         visible:
           id: ${output.saved.id.loginPrompt}
   # ❌
   - tapOn: ${output.article.text.saveButton}
   - assertVisible: "All articles"
   ```

   The key's group must match the selector type: `id:` ← `.id.`, `text:` ← `.text.`.
4. **Each file imports the selectors it uses** with `runScript`, at the top:
   `- runScript: ../../selectors/pages/<screen>.js`. Callers never rely on a
   selector file loaded by someone else.
5. **Tests don't tap or assert directly**: they call page/component actions with
   `runFlow` + `label`, passing inputs via `env`. Read a test top-down as the user story.
6. **Every test is independent**: it starts with `common/launch_clean.yaml` and
   never calls another test.
7. **Inputs are explicit**: each action documents its `env` inputs, precondition
   and postcondition in its header.
8. **Check optional elements only where they appear.** Each conditional check for
   an absent element costs ~7 s (see `docs/troubleshooting.md`).
9. **Platform differences** go inside the page action with
   `runFlow: {when: {platform: iOS|Android}}`, not in separate test files.

Quick check before committing (both must print nothing):

```bash
# shorthand (untyped) element access
grep -rnE '^\s*-?\s*(tapOn|assertVisible|assertNotVisible|doubleTapOn|longPressOn):\s*\S' --include='*.yaml' .maestro
grep -rnE '^\s*(visible|notVisible):\s*\S' --include='*.yaml' .maestro
# literal selector values outside selectors/
grep -rnE "(id|text):\s*['\"][^$]" --include='*.yaml' .maestro
```

## How to add…

**A selector** — add it to `selectors/pages/<screen>.js` (or
`selectors/components/<name>.js`) under `id` or `text`, after verifying it on
the device (Maestro Studio or MCP `inspect_screen`) and following the selector policy:

```js
output.saved = {
  id: { loginPrompt: 'reading-list-login' },
  text: { allArticlesTab: 'All articles' },
};
```

**A page** — `selectors/pages/<screen>.js` plus `pages/<screen>/` with one
`<verb_noun>.yaml` per action or assertion:

```yaml
# Save the open article. Precondition: article loaded (wait_until_loaded.yaml).
appId: ${MAESTRO_APP_ID}
---
- runScript: ../../selectors/pages/article.js
- tapOn:
    text: ${output.article.text.saveButton}
- assertVisible:
    text: ${output.article.text.savedButton}
```

**A component** — when the same widget appears on more than one screen:
`selectors/components/<name>.js` plus `components/<name>/<verb_noun>.yaml`.

**A test** — `tests/<domain>/<verb_noun>.yaml`:

```yaml
appId: ${MAESTRO_APP_ID}
name: <What the user achieves>
tags: [smoke|regression, <domain>, ios]
---
- runScript: ../../data/articles.js
- runFlow:
    file: ../../common/launch_clean.yaml
    label: Launch with a clean state
- runFlow:
    file: ../../pages/onboarding/skip_onboarding.yaml
    label: Skip onboarding
- runFlow:
    file: ../../pages/<screen>/<action>.yaml
    label: <Business step>
    env:
      TITLE: ${output.articles.apollo11.title}
```

New domain? Create `tests/<domain>/`; `config.yaml` picks it up automatically.

**Test data** — add an entry to a file in `data/` (or a new `data/<topic>.js`).
Secrets never go in `data/`: they come from `.env` as `MAESTRO_*` variables.

## Run

```bash
cp .env.example .env                      # once; set MAESTRO_APP_ID and DEVICE_ID
scripts/run_tests.sh                      # all tests
scripts/run_tests.sh --include-tags=smoke # smoke suite
scripts/run_tests.sh .maestro/tests/search                     # one domain
scripts/run_tests.sh .maestro/tests/search/open_article.yaml   # one test
```

The script loads `.env`, generates a `RUN_ID`, and writes debug output plus a
JUnit report to `artifacts/maestro/<run-id>/` (ignored by Git).

## Variables

| Variable           | Where it is set        | Secret? | Purpose                                            |
| ------------------ | ---------------------- | ------- | -------------------------------------------------- |
| `MAESTRO_APP_ID`   | `.env` / CI            | No      | iOS bundle ID / Android package (required)         |
| `MAESTRO_PLATFORM` | `.env` / CI            | No      | `ios` / `android`                                  |
| `MAESTRO_RUN_ENV`  | `.env` / CI            | No      | `sample`, later `staging`                          |
| `MAESTRO_RUN_ID`   | `run_tests.sh` / CI    | No      | Namespaces artifacts and test data                 |
| `DEVICE_ID`        | `.env` (runner only)   | No      | Target device for `maestro --device`               |
| `REPORT_FORMAT`    | `.env` (runner only)   | No      | `JUNIT` (default), `HTML`, `HTML-DETAILED`, `NOOP` |

Maestro exposes shell variables prefixed `MAESTRO_` to flows, which is why flow
variables use that prefix. Secrets for a real app (`MAESTRO_TEST_USERNAME`, …)
follow the same path: `.env` locally, CI secret store in pipelines.

## Tags

`smoke` (PR gate, critical journeys) · `regression` (broader coverage) ·
domain tag (`onboarding`, `search`, `reading_list`, `history`) · platform tag
(`ios`; add `android`/`cross-platform` only after a verified run) · `critical`.

## Design decisions

- **POM and `.env` runner** were adopted on purpose, overriding two rules of the
  original plan (`docs/tasks/step-01-setup.md`: "no page-object library",
  "no homemade `.env` loader") to make the suite easier to navigate and to run
  like a real project. The runner only sources `.env`; it adds no dependency.
- **Selectors isolated in `selectors/` and grouped by type** give one source of
  truth per screen/component, make the selector type visible at every use site,
  and work with Maestro's built-in GraalJS (`runScript`) without a build step.
- `platform.*.disableAnimations` is a Maestro Cloud-only setting and is not configured.
- Use either the CLI or Maestro MCP on a device at a time; see `docs/troubleshooting.md`.
