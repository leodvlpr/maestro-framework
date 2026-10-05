# Maestro mobile automation framework

A maintainable mobile UI automation framework built with
[Maestro](https://docs.maestro.dev/). It currently targets the public
Wikipedia sample app from `maestro download-samples` and is structured so a
real application can replace that sample later without redesigning the suite.

**Status:** POM restructure — 5 tests in 4 domains (3 smoke, 2 regression) on iOS.
Android is not verified yet. The phased plan is in
[`docs/tasks/step-01-setup.md`](docs/tasks/step-01-setup.md).

## Prerequisites

| Tool            | Verified version                     |
| --------------- | ------------------------------------ |
| Maestro CLI     | 2.11.0 (official release)            |
| Java            | 17                                   |
| Xcode           | 27.0, iOS 26.5 simulator (iPhone 17) |
| Android SDK/ADB | Not set up yet                       |

## Quick start (iOS simulator)

```bash
# 1. Get the sample SUT (ignored folder) and install it on a booted simulator
maestro download-samples -o work/maestro-samples
unzip -q -o work/maestro-samples/samples/wikipedia.zip -d work/maestro-samples/ios -x '__MACOSX/*'
xcrun simctl install <simulator-udid> work/maestro-samples/ios/Wikipedia.app

# 2. Configure your target (once) and run the smoke suite
cp .env.example .env        # set MAESTRO_APP_ID and DEVICE_ID
scripts/run_tests.sh --include-tags=smoke
```

Results, screenshots, logs and a JUnit report land in `artifacts/maestro/<run-id>/` (ignored).

## Architecture

```text
.
├── .maestro/
│   ├── selectors/           # ALL identifiers, grouped by type (id / text)
│   ├── tests/<domain>/      # tests by business domain (the only discovered flows)
│   ├── pages/<screen>/      # Page Objects: actions and assertions per screen
│   ├── components/<name>/   # actions of shared UI components (tab bar, first-run tips)
│   ├── common/              # app lifecycle (launch_clean)
│   └── data/                # test data
├── scripts/run_tests.sh     # loads .env and runs Maestro with per-run output
├── docs/                    # SUT contract, strategy, policies, CI, troubleshooting
├── artifacts/               # run output (ignored, created at runtime)
└── work/                    # sample downloads and scratch data (ignored)
```

All tests use `appId: ${MAESTRO_APP_ID}`; the app identifier always comes from
`.env` or CI. Every element access declares its type (`id:` / `text:`) and
takes its value from `.maestro/selectors/`. See [`.maestro/README.md`](.maestro/README.md)
for conventions, how to add selectors/pages/components/tests, and variables.

## Documentation

- [SUT contract](docs/sut-contract.md) — verified app IDs, journeys, locators, reset behavior
- [Test strategy](docs/test-strategy.md) — suites, test inventory, isolation, flake policy
- [Selector policy](docs/selector-policy.md) — where selectors live, explicit types, preference order
- [CI/CD](docs/ci-cd.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Real SUT migration](docs/real-sut-migration.md)
