# Maestro mobile automation framework

A maintainable mobile UI automation framework built with
[Maestro](https://docs.maestro.dev/). It currently targets the public
Wikipedia sample app from `maestro download-samples` and is structured so a
real application can replace that sample later without redesigning the suite.

**Status:** Phase 2 of 8 — workspace scaffolded; one smoke flow passing on iOS.
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

# 2. Run the smoke suite from the repository root
maestro --device <simulator-udid> test \
  -e APP_ID=org.wikimedia.wikipedia \
  -e TARGET_PLATFORM=ios \
  -e RUN_ENV=sample \
  -e RUN_ID=local-001 \
  --test-output-dir artifacts/maestro/local-001 \
  --include-tags=smoke \
  .maestro
```

Results, screenshots and logs land in `artifacts/maestro/local-001/` (ignored).

## Architecture

```text
.
├── .maestro/            # Maestro workspace: config, flows, components, scripts, data
├── docs/                # SUT contract, strategy, policies, CI, troubleshooting
├── artifacts/           # Run output (ignored, created at runtime)
└── work/                # Sample downloads and scratch data (ignored)
```

All executable flows use `appId: ${APP_ID}`; the app identifier is always
supplied at runtime. See [`.maestro/README.md`](.maestro/README.md) for flow
conventions and variables.

## Documentation

- [SUT contract](docs/sut-contract.md) — verified app IDs, journeys, locators, reset behavior
- [Test strategy](docs/test-strategy.md)
- [Selector policy](docs/selector-policy.md)
- [CI/CD](docs/ci-cd.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Real SUT migration](docs/real-sut-migration.md)
