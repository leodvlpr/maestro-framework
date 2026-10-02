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

## A visible element is reported as not visible (iOS)

First-run tips and prompts hide the content behind them from the accessibility
tree. Dismiss them first; the list is in
[`sut-contract.md`](sut-contract.md#interruptions-first-run-tips-and-prompts).
