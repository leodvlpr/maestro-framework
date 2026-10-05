# Selector policy

How UI elements are identified in this framework. Applies to every file under
`.maestro/`.

## Where selectors live

All identifiers live in `.maestro/selectors/`, one file per screen or shared
component, and are imported with `runScript` by the file that uses them:

```text
.maestro/selectors/
├── pages/       onboarding.js · explore.js · search.js · article.js · saved.js · history.js
└── components/  tab_bar.js · tips.js
```

Each file defines one object, grouped by selector type:

```js
// .maestro/selectors/pages/saved.js
output.saved = {
  id: {
    loginPrompt: 'reading-list-login',
  },
  text: {
    allArticlesTab: 'All articles',
    loginPromptCloseButton: 'Close',
  },
};
```

- `id` — resource IDs / accessibility identifiers. Used only with `id:`.
- `text` — visible text or accessibility labels (Maestro matches them as
  full-string regex, case-insensitive). Used only with `text:`.
- Keep both groups even when one is empty (`id: {}`), so the shape is uniform.
- Add a short comment when a value is non-obvious (state-dependent label,
  first-visit prompt, parent/child quirk).

No `tests/`, `pages/`, `components/` or `common/` file contains a literal
selector value. The only values written directly in a flow are inputs that
come from test data (`data/`), e.g. an article title.

## Explicit selector type

Every element access names its type. The shorthand string form is not allowed:

```yaml
# ✅ allowed
- tapOn:
    id: ${output.article.id.backButton}
- tapOn:
    text: ${output.onboarding.text.skipButton}
- assertVisible:
    text: ${TITLE}
- extendedWaitUntil:
    visible:
      text: ${output.tips.text.gotItButton}
    timeout: 20000
- runFlow:
    when:
      visible:
        id: ${output.saved.id.loginPrompt}
    commands: [...]

# ❌ not allowed
- tapOn: ${output.onboarding.text.skipButton}
- assertVisible: "All articles"
- repeat:
    while:
      visible: "Got it"
```

The group in the key must match the type: `id:` ← `output.<name>.id.*`,
`text:` ← `output.<name>.text.*`.

Combined matchers are allowed when one attribute is not enough, e.g. the tab bar,
where the button carries `selected` and its icon child carries the id:

```yaml
- assertVisible:
    selected: true
    containsChild:
      id: ${output.tabBar.id.saved}
```

## Preference order

1. **Resource ID / accessibility identifier** supplied by the app (`id`).
2. **Unique accessibility label or visible text** that represents user-facing
   behaviour (`text`).
3. **Text regex** only where part of the value is intentionally variable
   (escape regex characters: `First crewed Moon landing \\(1969\\)` in JS).
4. **Coordinates** only as a last resort, with a comment explaining the
   limitation and a reference to replace it. None are used today.

On the Wikipedia sample, IDs exist for the tab bar, back button, toolbar,
profile button and some overlays; onboarding, search and lists only expose text.
When migrating to a real app, request accessibility identifiers from the app
team and move entries from `text` to `id`.

## Verifying a selector

1. Inspect the live screen with Maestro Studio or MCP `inspect_screen`, and
   copy values verbatim from the hierarchy — never from a screenshot.
2. Prefer values that are stable across locales and app states.
3. Check the element is not hidden by an overlay: first-run tips hide the
   content behind them from the accessibility tree (`docs/sut-contract.md`).
4. Add it to the right file and group, then exercise it through a test.

## Enforcement

Run before committing (each must print nothing):

```bash
grep -rnE '^\s*-?\s*(tapOn|assertVisible|assertNotVisible|doubleTapOn|longPressOn):\s*\S' --include='*.yaml' .maestro
grep -rnE '^\s*(visible|notVisible):\s*\S' --include='*.yaml' .maestro
grep -rnE "(id|text):\s*['\"][^$]" --include='*.yaml' .maestro
```
