# Troubleshooting

> Started in Phase 2; completed in Phase 8.

## Output appears outside the repository

Maestro resolves `testOutputDir` (in `.maestro/config.yaml`) and
`--test-output-dir` against the **current working directory**, not the
workspace folder. Run all commands from the repository root.

## `Device became unreachable` from Maestro MCP

Observed on iOS after running the Maestro CLI while an MCP session was already
connected to the same simulator: every MCP call (even a screenshot) failed with
`Device became unreachable during setPermissions`. Reconnect the MCP server
(`/mcp` in Claude Code) before using MCP again.

The reverse also happens: with an MCP session connected, a CLI run once stopped
mid-flow without an error (its log ends during `inputText`) while two XCTest
runner processes were alive. **Use one tool per device at a time** — either the
CLI or MCP — and reconnect MCP after switching back from the CLI.

## A visible element is reported as not visible (iOS)

First-run tips and prompts hide the content behind them from the accessibility
tree. Dismiss them first; the list is in
[`sut-contract.md`](sut-contract.md#interruptions-first-run-tips-and-prompts).

## Tests are slow around optional elements

Every conditional check (`runFlow: when: visible`, `repeat: while: visible`) for
an element that is **not** on screen waits Maestro's optional lookup timeout
(~7 s on 2.11.0). A generic "dismiss every possible tip" step called on every
screen cost over a minute per test. Check an optional element only on the
screen where it can appear (`components/tips/dismiss_popover.yaml` after search,
`components/tips/dismiss_got_it_tips.yaml` on article load,
`pages/saved/dismiss_login_prompt.yaml` on Saved).

## Run report

`scripts/run_tests.sh` writes `artifacts/maestro/<run-id>/report.xml` (JUnit).
For a failed step, open `<run-id>/<timestamp>/<test name>/screenshots/` and the
matching `screen-hierarchy/*.json` to see what Maestro could read at that moment.

## `${output.<name>...}` resolves to empty / element not found

The selector file was not imported in the flow that uses it. Each page,
component or test must `runScript` its own selector file from
`.maestro/selectors/` before referencing it. Also check the key's group matches
the type (`id:` ← `.id.`, `text:` ← `.text.`).
