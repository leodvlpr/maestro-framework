# Project #3 — Production-oriented Maestro mobile automation framework

## Purpose

Build a maintainable mobile UI automation framework with [Maestro](https://docs.maestro.dev/) against a public/sample mobile application first. The framework must run locally on Android and iOS where the sample supports them, produce useful failure evidence, and be structured so a real application can replace the sample SUT (system under test) later without redesigning the suite.

This is an implementation specification for Claude Code. Execute it in phases; do not attempt to build everything in one change.

> Important technical decision: Maestro now uses **GraalJS** by default and its documentation discourages Rhino. Use the portable JavaScript patterns in this plan with GraalJS. Do not enable Rhino unless a concrete legacy requirement requires it and the installed Maestro version documents the exact opt-in mechanism. Rhino is a compatibility concern, not the framework default.

## Objectives and definition of done

The finished framework must:

- Run a small, deterministic smoke suite locally against an installed public/sample SUT.
- Organize broader, independent regression journeys separately from smoke tests.
- Use reusable, parameterized subflows without making individual journeys hard to read.
- Receive the app identifier, environment values, and secrets at runtime; no secret or environment-specific identifier is embedded in test logic.
- Support Android first and an iOS path when the chosen sample app/binary is available. Platform-only behavior must be isolated.
- Generate screenshots, logs, and test output on failure and preserve them in CI artifacts.
- Have a CI design with a fast pull-request smoke gate and a scheduled/full regression gate.
- Document the SUT contract, how to execute tests, how to add a journey, and how to replace the sample SUT.
- Pass the validation specified at the end of every phase.

Non-goals for the first implementation:

- Do not automate a production customer account or production data.
- Do not add an API-test framework, a general-purpose Node/Python test runner, a database, or a page-object library. Maestro YAML and its built-in JavaScript are sufficient initially.
- Do not claim Android/iOS parity until the same journey has actually passed on both platforms.
- Do not hide instability with broad retries or arbitrary waits.

## Non-negotiable execution rules for Claude Code

Apply these rules at the start of **every phase**, before changing files:

1. Inspect the repository: read `AGENTS.md`/`CLAUDE.md`/existing contributor instructions if present; inspect the top-level tree; inspect `git status`; and identify existing CI, mobile tooling, and Maestro files. Do not overwrite or reformat unrelated user changes.
2. State the files you intend to add or alter and why. If the repository already has an automation convention, adapt this plan to it rather than creating a parallel structure.
3. Make only the changes for the current phase. Prefer built-in Maestro and shell/CI capabilities over new dependencies.
4. Never commit credentials, API keys, private app binaries, device identifiers, real-user data, or generated artifacts. Add appropriate ignore rules before generating artifacts.
5. Run the phase validation after the change. Record the exact command, platform/device, and result in the phase notes or pull-request description. Fix failures caused by the phase before continuing.
6. Stop at the phase boundary for review. If the repository uses Git, make a small, focused commit only when that is consistent with the repository workflow and authorized by the user.

If a required fact is unknown, discover it from the installed app/device or official Maestro documentation; do not invent selectors, package IDs, sample paths, CI secrets, or command flags.

## Initial SUT strategy

Use `maestro download-samples` as the bootstrap SUT. It is intended to download sample flows and app builds for Android and iOS. Treat the downloaded sample as an externally supplied fixture, not source code owned by this repository.

The implementation must do the following before authoring functional journeys:

1. Run `maestro --version` and save the version in the implementation notes/README.
2. Run `maestro download-samples` in a temporary, ignored location such as `work/maestro-samples/` (not in a tracked source folder).
3. Inspect the downloaded files, sample documentation, and existing sample flows. Install the relevant sample binary on the target emulator/simulator.
4. Discover the actual Android package name and iOS bundle identifier from the installed app or the sample metadata. Do not copy an identifier from an old tutorial without verifying it.
5. Explore the app manually and with Maestro Studio/recording. Capture the exact, stable user journeys the sample really supports.
6. Create `docs/sut-contract.md` from those observations before creating a test suite. It becomes the explicit adapter boundary between the framework and the sample app.

The SUT contract must include:

| Field                      | Required content                                                        |
| -------------------------- | ----------------------------------------------------------------------- |
| SUT name/source            | Sample name, source command, and date/version or checksum if available  |
| Binary handling            | Where it is acquired and where it is installed; binaries remain ignored |
| Android app ID             | Verified installed package ID                                           |
| iOS app ID                 | Verified installed bundle ID, or `not available` with the reason        |
| Supported journeys         | Actual flows observed in this sample, with a short business description |
| Stable locators            | Accessibility IDs/labels or text verified on each platform              |
| Known platform differences | Permissions, labels, navigation, keyboard, or unsupported features      |
| Reset and cleanup          | How data/state is reset and how created data is removed or isolated     |
| Replacement mapping        | The intended real-app equivalents for each capability and locator       |

If the downloaded sample is too shallow to demonstrate meaningful journeys, use the documented Contacts application only as a temporary Android learning fixture (`com.google.android.contacts`) and document the limitation. Do not silently mix a sample app and Contacts in the same suite: keep each SUT contract and suite target distinct.

## Prerequisites

Install and verify only what is needed for the platform being exercised.

| Area             | Requirement                                                       | Verification                                                            |
| ---------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Maestro          | Current supported Maestro CLI                                     | `maestro --version`, then `maestro --help`                              |
| Android          | Android SDK/ADB and a booted emulator or debugging-enabled device | `adb devices`; confirm the sample app is installed                      |
| iOS (macOS only) | Xcode command-line tools and a booted iOS Simulator               | `xcrun simctl list devices booted`; confirm the sample app is installed |
| Access           | Internet only to obtain the public sample and official tools      | Do not require a cloud account for local phases                         |
| CI               | A runner capable of the selected platform                         | Confirm this before writing a platform-specific CI job                  |

Do not pin an unverified Maestro version in a new dependency manager. Initially document the version proven locally. Once CI exists, pin the version in the CI setup or approved action according to the repository's dependency policy, then update the local setup instructions to match.

## Target architecture

The test repository uses one Maestro workspace at `.maestro/`. Executable test cases are separate from reusable components and from platform adapters.

```text
repository-root/
├── .maestro/
│   ├── config.yaml                    # Discovery, safe defaults, platform settings
│   ├── flows/
│   │   ├── smoke/                     # Small PR-critical end-to-end journeys
│   │   ├── regression/                # Independent broader journeys
│   │   ├── components/                # Reusable subflows; never discovered as tests
│   │   │   ├── app/
│   │   │   ├── navigation/
│   │   │   ├── permissions/
│   │   │   ├── assertions/
│   │   │   └── platform/
│   │   │       ├── android/           # Android adapter subflows
│   │   │       └── ios/               # iOS adapter subflows
│   │   ├── platform/
│   │   │   ├── android/               # Android-only executable journeys
│   │   │   └── ios/                   # iOS-only executable journeys
│   │   └── support/                   # Non-executable helpers only
│   ├── scripts/
│   │   └── js/                        # Small Maestro runScript helpers
│   ├── data/
│   │   ├── fixtures/                  # Safe, versioned non-secret data
│   │   └── schemas/                   # Data and SUT-contract examples, if useful
│   └── README.md                      # Framework-specific quick start
├── docs/
│   ├── sut-contract.md
│   ├── test-strategy.md
│   ├── selector-policy.md
│   ├── ci-cd.md
│   ├── troubleshooting.md
│   └── real-sut-migration.md
├── scripts/                           # Minimal optional local launch wrappers only
├── .github/workflows/                 # Only if this is a GitHub repository
├── artifacts/                         # Ignored Maestro output; created at runtime
├── work/                              # Ignored local sample downloads/scratch data
├── .gitignore
└── README.md
```

If the repository already uses a different root (for example, a mobile app repository with `qa/maestro/`), retain that root but preserve the separation between executable suites, components, platform adapters, data, and generated output.

### Boundary that permits SUT replacement

All executable flows start with `appId: ${APP_ID}`. The command or CI job supplies `APP_ID`; it is never hard-coded in a journey.

```yaml
# .maestro/flows/smoke/create_record.yaml
appId: ${APP_ID}
name: Create a sample record
tags:
  - smoke
  - critical
  - android
---
- runFlow:
    file: ../components/app/launch_clean.yaml
- runFlow:
    file: ../components/navigation/open_create_record.yaml
- runFlow:
    file: ../components/assertions/assert_record_visible.yaml
    env:
      RECORD_NAME: ${RUN_RECORD_NAME}
```

The real app migration should normally change only these layers, in this order:

1. Runtime configuration and the SUT contract (`APP_ID`, install/build source, test account/environment).
2. App/navigation/permission components and selector map where the real UI differs.
3. A journey only where the business behavior itself differs.

If replacing the sample requires rewriting every journey, the components are too application-specific or too large; refactor the boundary before adding more tests.

## Configuration and environment strategy

### Workspace configuration

Create `.maestro/config.yaml` with only portable suite discovery and safe output/platform settings. It must discover executable test folders and explicitly exclude components, support flows, and platform helper directories.

Example shape; validate the glob behavior in the installed Maestro version before relying on it:

```yaml
flows:
  - flows/smoke/**/*.yaml
  - flows/regression/**/*.yaml
  - flows/platform/**/*.yaml
  - "!flows/components/**"
  - "!flows/support/**"
testOutputDir: artifacts/maestro
platform:
  android:
    disableAnimations: true
  ios:
    disableAnimations: true
```

Do not put an `appId` in `config.yaml`. Keep it in executable flow headers as `${APP_ID}` so the same flow can target Android/iOS or a later real SUT.

### Runtime variables

Use uppercase names, document every variable, and pass non-secret values using `-e NAME=value`. Every variable should have one owner and one purpose.

| Variable                | Source                        | Secret? | Example purpose                                             |
| ----------------------- | ----------------------------- | ------- | ----------------------------------------------------------- |
| `APP_ID`                | Local command or CI matrix    | No      | Android package or iOS bundle identifier                    |
| `TARGET_PLATFORM`       | Local command or CI matrix    | No      | `android` / `ios`, used only for known conditional behavior |
| `RUN_ENV`               | Local command or CI matrix    | No      | `sample`, `staging`                                         |
| `RUN_ID`                | CI run ID or generated safely | No      | Namespaces generated test data/artifacts                    |
| `RUN_RECORD_NAME`       | Generated by a script/flow    | No      | Unique entity name used by a journey                        |
| `MAESTRO_TEST_USERNAME` | Secret store/environment      | Yes     | Non-production test account                                 |
| `MAESTRO_TEST_PASSWORD` | Secret store/environment      | Yes     | Non-production test account                                 |
| `MAESTRO_CLOUD_API_KEY` | Secret store/environment      | Yes     | Maestro Cloud authentication, only if cloud is adopted      |

Maestro CLI makes shell variables with the `MAESTRO_` prefix available to flows. Use that facility only for secrets or CI-controlled values. Do not create a homemade `.env` loader or add a dotenv dependency. Provide `.env.example` only as a commented documentation template and ensure `.env` is ignored.

Examples (replace values with those verified in the SUT contract):

```bash
maestro test \
  -e APP_ID='verified.sample.android.id' \
  -e TARGET_PLATFORM=android \
  -e RUN_ENV=sample \
  -e RUN_ID=local-001 \
  --test-output-dir artifacts/maestro/local-001 \
  --include-tags=smoke \
  .maestro
```

```bash
maestro test \
  -e APP_ID='verified.sample.ios.id' \
  -e TARGET_PLATFORM=ios \
  -e RUN_ENV=sample \
  -e RUN_ID=local-ios-001 \
  --test-output-dir artifacts/maestro/local-ios-001 \
  --include-tags=smoke \
  .maestro
```

The literal IDs above are placeholders in this specification. Replace them only after verifying the installed sample; do not commit the placeholder values as a working configuration.

### Secret policy

- Secrets enter through the CI secret store, Maestro Cloud secret facility (if enabled), or the developer's shell; they never enter YAML, JavaScript, fixtures, screenshots intentionally, logs, issues, or documentation.
- Use dedicated, least-privilege, non-production accounts. Do not use personal accounts.
- Mask secrets in CI. Avoid `console.log` of all environment variables or any credential-bearing value.
- Treat screenshots, page hierarchies, and videos as potentially sensitive. Use sample/sanitized data first and set artifact retention appropriately.

## Flow and selector conventions

### File naming and test shape

- File names: lowercase `verb_noun.yaml`, for example `create_record.yaml` or `edit_profile.yaml`.
- One executable file equals one independently valuable user journey. It must be runnable alone on a clean device.
- Begin executable flows with `appId: ${APP_ID}`, a descriptive `name`, and tags.
- A flow must state its preconditions in a short YAML comment or its documentation entry.
- Reusable files live under `components/`, take explicit `env` inputs when needed, and should not carry suite tags.
- `runFlow` calls use `file:` and a meaningful `label:` for report readability. Pass only the variables the component needs.
- Keep component paths relative to the calling flow and verify them by executing the calling journey; never rely on an editor resolving a path.

### Selector policy

Document and enforce this preference order:

1. Stable accessibility identifier / resource ID supplied by the app team.
2. Stable, unique accessibility label or visible text representing user-facing behavior.
3. Text regex only where minor dynamic portions are intentionally variable.
4. Coordinates only as a last resort, with a comment explaining the technical limitation and an issue/reference to replace it.

Do not create a generic page-object class hierarchy. If several flows need the same selector sequence, make a small named subflow. If only one flow needs it, keep the action in that flow.

Use `assertVisible`, `assertNotVisible`, and targeted waits to express observable business outcomes. Do not use fixed sleeps except for a documented, unavoidable platform animation; first try a state-based assertion/wait and record why it failed.

### Standard reusable subflows

Build only the subflows justified by observed SUT behavior. The initial candidates are:

| Component                                     | Responsibility                                                   | Inputs                                      |
| --------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------- |
| `app/launch_clean.yaml`                       | Start from known app state; handle only verified launch behavior | `CLEAR_STATE` if a platform needs variation |
| `permissions/handle_initial_permissions.yaml` | Handle a known permission dialog idempotently                    | `TARGET_PLATFORM`, permission scenario      |
| `navigation/open_home.yaml`                   | Reach the durable landing screen                                 | None                                        |
| `navigation/open_create_record.yaml`          | Reach the creation form                                          | None                                        |
| `navigation/open_record_by_name.yaml`         | Find a record created by the test                                | `RECORD_NAME`                               |
| `assertions/assert_record_visible.yaml`       | Verify a domain-level outcome                                    | `RECORD_NAME`                               |
| `app/return_to_known_state.yaml`              | Navigate or reset safely after a journey                         | None                                        |

Do not create generic `tap`, `type`, or `wait` wrappers. They obscure failures and add no domain value.

## JavaScript: allowed use, output state, and Rhino compatibility

Maestro JavaScript executes in a restricted sandbox: it cannot use the local filesystem or Node packages. Keep JavaScript short, deterministic, and directly test-related.

Use the least powerful option that works:

1. Inline `${...}` expression for a one-line default, string operation, or platform condition.
2. `evalScript` for a short calculation or to write a value to Maestro's `output` object.
3. `runScript` for a reusable, tested helper in `.maestro/scripts/js/`.

Permitted initial use cases:

- Generate a collision-resistant, non-sensitive test record name using `RUN_ID` and a timestamp/random suffix.
- Normalize a display string, calculate an expected value, or parse an integer supplied as a CLI string.
- Set `output.*` values used only by the current flow.
- Conditional platform behavior that cannot be isolated in a platform subflow.

Example:

```yaml
- evalScript: ${output.recordName = 'e2e_' + RUN_ID + '_' + new Date().getTime()}
- runFlow:
    file: ../components/navigation/open_record_by_name.yaml
    env:
      RECORD_NAME: ${output.recordName}
```

Rules:

- Do not put UI steps, credentials, long business logic, or network setup into JavaScript.
- Do not depend on Node APIs, local files, installed packages, or browser APIs.
- `console.log` may log a short non-sensitive execution marker; use one interpolated string, not multiple arguments.
- Keep a helper's inputs/outputs in a comment header or adjacent documentation.
- If a helper becomes complex, first ask whether a backend fixture API or a simpler test-data design is the better boundary.

### Rhino policy

No production flow enables Rhino initially. If an existing organization requires Rhino:

1. Record the business/technical requirement and the exact Maestro version.
2. Verify the current official instruction for enabling it; do not guess a CLI flag or environment variable.
3. Add one opt-in compatibility job, separate from the default suite.
4. Restrict shared JavaScript to the overlap of supported language features and execute the same JS-dependent smoke flow under both engines.
5. Remove the compatibility job when the legacy requirement ends.

## Test data, state, and cleanup

- Commit only small, synthetic, non-sensitive fixtures in `.maestro/data/fixtures/`.
- Give every created entity a `RUN_ID`-based unique namespace. A failed run must not collide with a later run.
- Prefer resetting a dedicated emulator/simulator snapshot or app state before each independent test. `clearState` is useful but does not necessarily remove data owned outside the app; verify its real effect for the SUT.
- Where a flow creates external data, add a verified cleanup subflow or document why a disposable device/snapshot is the cleanup mechanism.
- Keep seed/setup through the UI only during the sample-app phase unless the real SUT exposes an approved test-only setup API. If that API is later used, put it behind a documented, non-production fixture boundary and do not make the test outcome depend on an unverified API call.
- Ensure test data shown in screenshots is synthetic and recognizable as test data.

## Suite taxonomy and execution policy

| Suite                          | Tags                                               | Scope                                                         | Trigger                               | Time budget                                 |
| ------------------------------ | -------------------------------------------------- | ------------------------------------------------------------- | ------------------------------------- | ------------------------------------------- |
| Smoke                          | `smoke`, `critical`, `cross-platform`/platform tag | 2–5 business-critical, independent journeys                   | PR/push after the framework is stable | Aim for a few minutes per platform          |
| Regression                     | `regression`, feature/risk tags                    | Broader happy paths, boundaries, error states                 | Scheduled/nightly and pre-release     | Explicitly measured; keep tests independent |
| Platform-only                  | `android` or `ios` plus suite tag                  | System dialogs or UI behavior that is truly platform-specific | Relevant platform job                 | Separate result visibility                  |
| Quarantine (only if necessary) | `quarantine` plus owner/issue reference            | Known unstable test under investigation                       | Never PR blocking                     | Time-boxed; remove or fix, do not normalize |

Tag by purpose and risk, not by arbitrary folder alone. A smoke test should also carry `smoke`; a regression test should carry `regression`. Filter with tags only after direct folder execution is proven.

Do not retry a failing test automatically in the initial quality gate. A single controlled rerun in a non-blocking diagnostic job can collect evidence, but it must never turn a failing quality gate green or erase the initial failure.

## Android and iOS design rules

### Shared rules

- Run each flow against one explicitly selected target device. Do not let CI accidentally choose an arbitrary connected device.
- Use `${APP_ID}` in all executable flows and pass a verified ID for each platform.
- Maintain a platform matrix only for flows demonstrated to work on both platforms.
- Keep platform adapter subflows in `flows/components/platform/android/` or `flows/components/platform/ios/`. Reserve `flows/platform/<platform>/` for explicitly executable platform-only journeys.
- Record OS version, device model, locale, and Maestro version for every CI run.

### Android

- Confirm an emulator/device is booted and the sample APK is installed before Maestro starts; Maestro does not install an arbitrary APK for a local `maestro test` run.
- Prefer a dedicated emulator profile and clean snapshot. Verify permissions and keyboard behavior on that image.
- Use `clearState` only after confirming it produces the needed state. Do not assume it deletes OS-level test data.
- Use Android resource/accessibility IDs where available.

### iOS

- Treat iOS as a separate acceptance target: require a booted simulator and a simulator-compatible sample app build.
- Verify the bundle ID from the installed simulator app, plus the permission and keyboard behavior.
- Do not force an Android locator into iOS. Use a narrowly scoped iOS adapter when labels/controls differ.
- Document any unsupported sample capability as `not covered on iOS`, not as a passing cross-platform test.

## Reporting and artifacts

Every local and CI run writes to an ignored, uniquely named directory such as `artifacts/maestro/<run-id>/`. Use Maestro's `--test-output-dir` for the run-specific location.

Minimum artifact policy:

- On every failure: preserve Maestro test output, command/log output, failure screenshots, and the device/platform metadata.
- On smoke success: preserve lightweight result metadata; retain full media only if the team needs it for audit/debugging.
- Add intentional `takeScreenshot` checkpoints only at meaningful business states, not after every tap.
- Preserve output through CI's artifact mechanism even when the test command fails (an `always`/equivalent upload step).
- Never commit `artifacts/`, video, screenshots, downloaded app binaries, report XML/HTML, or sample download folders.

When Maestro Cloud is adopted, upload the **workspace folder**, not a lone flow, so dependent subflows and the workspace configuration are included. Use named flags and provide the cloud key and app/test credentials only from the secret store.

## CI/CD architecture

Choose the existing repository CI provider. Do not create a GitHub Actions workflow in a repository that uses another provider without user approval. If there is no CI and the repository is hosted on GitHub, GitHub Actions is the default proposal; ask before adding provider-specific external actions.

### Required CI stages

1. **Prepare** — checkout; install/pin Maestro according to the approved repository approach; provision one known emulator/simulator; obtain and install the approved sample binary or CI build.
2. **Preflight** — print non-sensitive versions; verify one target is available; verify the SUT is installed; fail early with diagnostics if not.
3. **Smoke quality gate** — execute only `smoke` flows with a run-specific artifact directory. This blocks pull requests once stable.
4. **Artifact upload** — always upload the run directory and a small metadata file, even after failure.
5. **Regression** — scheduled/nightly and/or release trigger, starting with Android. Add iOS only after its local suite is demonstrated.
6. **Optional cloud execution** — a separate, explicitly enabled path. It must use CI secrets, a named project, pinned app binary, and workspace-folder upload.

Use no sharding until the suite has enough independent tests to justify it and there are verified separate devices/runners. When introduced, use Maestro's supported sharding options and make `RUN_ID`/test data unique per shard using Maestro's shard variables.

### Quality gates

| Gate                    | Required evidence                                                                                   | Failure behavior                           |
| ----------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Configuration integrity | Every executable flow has required header/tags; component paths resolve through an executed journey | Block the phase/PR                         |
| Functional smoke        | All smoke flows pass once on the selected clean target                                              | Block after stability baseline is accepted |
| Regression              | Selected/full suite passes in scheduled/release environment                                         | Investigate; release policy set by team    |
| Cross-platform claim    | Same named cross-platform smoke journey passes on Android and iOS                                   | Do not label it cross-platform otherwise   |
| Artifact integrity      | Failure run produces uploadable output with platform/version metadata                               | Block CI hardening phase                   |
| Flake control           | No untriaged automatic retry makes a job pass                                                       | Quarantine only with owner, issue, expiry  |
| Security                | Secret scan/peer review sees no secrets or private binaries                                         | Block immediately                          |

## Documentation deliverables

At completion, the repository documentation must answer these questions without tribal knowledge:

- **Root `README.md`:** What the framework does, prerequisites, fastest Android smoke command, architecture diagram/tree, and links to detailed docs.
- **`.maestro/README.md`:** Flow conventions, runtime variable table, tags, how to add a new journey/component, and local command examples.
- **`docs/sut-contract.md`:** The verified sample SUT contract described above.
- **`docs/test-strategy.md`:** Risk-based scope, smoke/regression definitions, isolation, data lifecycle, platform policy, and flake policy.
- **`docs/selector-policy.md`:** Selector hierarchy, examples of allowed/disallowed selectors, and escalation path for missing accessibility IDs.
- **`docs/ci-cd.md`:** Trigger matrix, required secrets by name only, device images, artifact retention/location, failure triage, and cloud option.
- **`docs/troubleshooting.md`:** App not installed, invalid app ID, permission dialogs, keyboard/locale issues, selector diagnosis, device reset, artifact location.
- **`docs/real-sut-migration.md`:** Checklist for replacing app ID/binary, contract, test accounts, selectors, platform deltas, and CI configuration without leaking a real secret.

## Phased implementation checklist

Each phase is independently verifiable. Execute phases in order and stop when its acceptance criteria are not met.

### Phase 0 — Repository discovery and implementation record

**Goal:** Establish facts; make no speculative framework implementation.

1. Inspect repository instructions, source tree, Git status, existing CI, current mobile tools, and current test assets.
2. Record which directories are safe to use and whether the repository is a standalone automation project or an application repository.
3. Verify Maestro availability. If it is absent, follow the current official installation guide appropriate to the environment; do not add package-manager files unless the repository policy requires them.
4. Add or update a concise implementation note only if the repository has a documented place for it. Include Maestro version and intentionally unresolved decisions.

**Validation:** `maestro --version` succeeds, or installation is explicitly recorded as the blocker. `git status` contains only intentional changes.

**Acceptance:** No app IDs, selectors, flows, or CI assumptions are invented.

### Phase 1 — Obtain and characterize the sample SUT

**Goal:** Make the public sample app executable on one platform and write its contract.

1. Download samples into ignored `work/maestro-samples/`.
2. Inspect supplied sample flows and app builds. Start with Android if both platforms are available; record why if another platform is selected.
3. Create/boot the target device, install the sample, and verify its installed app identifier.
4. Execute an unmodified supplied sample flow first, retaining its output under ignored artifacts.
5. Manually explore the exact candidate journeys and record stable selectors and state cleanup behavior.
6. Create `docs/sut-contract.md`; set unsupported platform/features to `not available` rather than guessing.

**Validation:** A supplied or minimal observed flow launches the sample and reaches one verifiable screen. The command, app ID, target platform, and output directory are documented.

**Acceptance:** The team can reproduce a known-good launch from the contract alone.

### Phase 2 — Scaffold the Maestro workspace safely

**Goal:** Establish a clean structure, discovery behavior, and secret/artifact protection.

1. Create the `.maestro/` directory tree, `config.yaml`, placeholder READMEs, docs, and only the minimum `.gitignore` additions required for `.env`, app binaries, `work/`, and artifacts.
2. Configure discovery so an executable smoke folder is included and components/support are excluded. Do not assume a glob works—prove it with a real run.
3. Add a tiny `launch_app` smoke flow with `appId: ${APP_ID}` and a visible post-launch assertion observed in Phase 1.
4. Document the local command, including `APP_ID`, platform, run ID, and output directory. Do not create a wrapper script yet unless repeated manual commands reveal a real portability problem.

**Validation:** On the Phase 1 device, run the workspace with `-e APP_ID=<verified-id>` and `--include-tags=smoke`, then confirm its output directory is ignored. Confirm component files are not unintentionally discovered as executable tests.

**Acceptance:** A fresh clone with the documented prerequisite and sample can execute one named smoke flow without secrets.

### Phase 3 — Establish reusable components and data isolation

**Goal:** Introduce only proven abstractions and eliminate shared-state coupling.

1. Implement `launch_clean` and any verified permission component. Keep their behavior idempotent and documented.
2. Implement one observed navigation component and one business-outcome assertion component. Give every `runFlow` a label and explicit inputs.
3. Add a small JavaScript helper only if needed to create a unique, synthetic data value. Prefer `evalScript`; use `runScript` only for a reusable helper.
4. Add one safe fixture and document its schema/lifecycle if a journey needs fixed data.
5. Verify cleanup/reset behavior by running the same test twice on the same device; fix any coupling before adding more tests.

**Validation:** The composed smoke flow passes twice consecutively from a clean/known state, creates no unbounded persistent test data, and produces an understandable failure location if a component selector is intentionally broken then restored.

**Acceptance:** Components reduce repeated domain steps without hiding individual user-journey intent.

### Phase 4 — Build the Android smoke suite

**Goal:** Provide a small, risk-based PR gate on the observed sample SUT.

1. Choose 2–5 actual critical sample journeys. Good candidates are launch/navigation, create/save/verify, and a main search/detail journey—only if they exist in the sample.
2. Implement each as an independent file under `flows/smoke/`, with `smoke`, risk, and platform/cross-platform tags.
3. Include a clear start state, unique test data where required, a business assertion, and cleanup/reset.
4. Add meaningful screenshot checkpoint(s), not screenshots after every step.
5. Update test strategy and selector policy documentation with decisions proven by the flows.

**Validation:** Run the tag-filtered smoke workspace three times on the same declared Android image from the defined clean state. Retain all output and investigate every failure; do not add general retries.

**Acceptance:** All smoke tests pass in three consecutive local runs and can be explained by the documentation.

### Phase 5 — Add targeted regression coverage

**Goal:** Broaden coverage without slowing or destabilizing the smoke gate.

1. Add independently valuable happy-path, boundary, error/empty-state, and navigation/back-stack journeys actually supported by the SUT.
2. Put them under `flows/regression/` with `regression` and feature/risk tags.
3. Reuse Phase 3 components only when the behavior is the same. Refactor a component if its parameters become unclear instead of accumulating conditionals.
4. Add required negative assertions and data cleanup.
5. Establish a test inventory in `docs/test-strategy.md`: journey, risk, tags, data behavior, platform coverage, and owner/area.

**Validation:** Run the regression suite independently, then smoke followed by regression on the same device according to the documented reset model. Confirm neither suite depends on accidental ordering.

**Acceptance:** Regression expansion has not changed the smoke time budget or introduced shared state.

### Phase 6 — Prove or delimit iOS support

**Goal:** Make platform coverage factual.

1. Only start if an iOS-compatible sample build and a supported Simulator are available. Otherwise document the explicit blocker and proceed without marking the framework cross-platform.
2. Verify the installed iOS bundle ID and update the SUT contract.
3. Execute the shared launch smoke flow with the iOS `APP_ID`.
4. Run each candidate shared smoke journey. For genuine platform differences, add narrow iOS components/platform flows with `ios` tags and document the difference.
5. Use the same data-isolation and artifact policies as Android.

**Validation:** Each journey marked `cross-platform` passes on both recorded targets. iOS-only and Android-only tests are selected correctly by their tags/folders.

**Acceptance:** Documentation shows an accurate platform coverage matrix, including any omissions.

### Phase 7 — Add reporting and CI quality gates

**Goal:** Turn the demonstrated local smoke suite into reproducible automated feedback.

1. Inspect existing CI. Select its native approach; if none exists, propose the provider/workflow before adding it.
2. Implement the Android prepare/preflight/smoke/artifact stages. Pin the tested Maestro setup following repository policy and download/install the approved public sample in CI rather than committing it.
3. Create a metadata file containing non-sensitive run details: commit/ref, Maestro version, platform, device image, `APP_ID` value only if non-sensitive, suite, command form, and timestamp.
4. Ensure artifact upload happens on success and failure and that generated paths are ignored locally.
5. Trigger the pipeline on a non-protected branch/PR and intentionally demonstrate an assertion failure once to confirm artifacts can be retrieved, then restore the test and prove green.
6. Add scheduled regression after smoke is stable. Add iOS CI only after Phase 6 proves local iOS coverage and a suitable runner is available.

**Validation:** One green smoke CI run, one intentional red run with accessible diagnostics, then a restored green run. The PR gate has no credentials in logs or repository files.

**Acceptance:** A reviewer can determine why a failure occurred without reproducing it locally in the first instance.

### Phase 8 — Harden, document, and prepare real-SUT migration

**Goal:** Finish a portfolio-quality framework, not just working flows.

1. Complete all documentation deliverables and update commands to match the exact final layout.
2. Add `docs/real-sut-migration.md` with an ordered dry-run checklist: obtain approved build, verify app IDs, create dedicated test accounts, define backend environment, update SUT contract, map selectors, run smoke locally, then enable CI.
3. Review every YAML and JS file for secrets, hard-coded sample app IDs outside documented examples, arbitrary sleeps, brittle coordinate taps, undocumented retries, and unintentionally executable components.
4. Review CI permissions, secret scope, artifact retention, and the absence of private app binaries in Git history/current status.
5. Execute the final local smoke and regression commands from the README on the documented target. Execute the CI smoke path once more.

**Validation:** All documented commands work as written; `git status` contains no generated outputs or secrets; all defined quality gates pass; the coverage matrix contains only verified claims.

**Acceptance:** A new contributor can follow the README to run smoke tests, add a new journey using the conventions, and understand exactly what must change to target a real app.

## Final review checklist

- [ ] Repository instructions were read before each implementation phase.
- [ ] The sample SUT and both app IDs (where applicable) were verified on actual targets.
- [ ] All executable flows use `appId: ${APP_ID}`.
- [ ] Components are excluded from suite discovery and invoked from an executable journey.
- [ ] Smoke and regression suites are independently runnable and tagged.
- [ ] Test data is synthetic, isolated, and cleaned/reset.
- [ ] JavaScript is minimal, portable, and does not depend on Rhino/Node/filesystem behavior.
- [ ] Android and iOS claims are backed by real runs, not folder names.
- [ ] Failure output is retained locally and in CI without committing artifacts.
- [ ] Secrets, binaries, and local files are ignored and absent from Git.
- [ ] CI smoke blocks only after a demonstrated stability baseline; regressions run on the planned schedule.
- [ ] README and migration guide match the implemented repository.

## Official references to consult during implementation

- [Maestro CLI commands and options](https://docs.maestro.dev/maestro-cli/maestro-cli-commands-and-options) — sample download, local test execution, output directory, devices, sharding, and cloud options.
- [Run tests on Maestro Cloud](https://docs.maestro.dev/maestro-cloud/run-tests-on-maestro-cloud) — sample binaries and workspace-folder upload guidance.
- [Project/workspace configuration](https://docs.maestro.dev/maestro-flows/workspace-management/project-configuration) and [workspace configuration reference](https://docs.maestro.dev/reference/workspace-configuration) — discovery, output, tags, and platform settings.
- [Parameters and constants](https://docs.maestro.dev/maestro-flows/flow-control-and-logic/parameters-and-constants) and the [FAQ for varying app IDs](https://docs.maestro.dev/extra-materials/troubleshooting/faq) — `${APP_ID}`, runtime values, and secret-safe parameters.
- [runFlow](https://docs.maestro.dev/reference/commands-available/runflow) — reusable subflows and passing scoped inputs.
- [JavaScript overview](https://docs.maestro.dev/maestro-flows/javascript/javascript-overview) and [runScript](https://docs.maestro.dev/reference/commands-available/runscript) — sandbox limits, GraalJS/Rhino policy, `output`, and reusable scripts.
- [Maestro Android support](https://docs.maestro.dev/get-started/supported-platform/android) and [QuickStart](https://docs.maestro.dev/get-started/quickstart) — installed-app expectations, cross-platform app IDs, and platform examples.
