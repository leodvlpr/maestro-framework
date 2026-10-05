# Real SUT migration

> Draft; completed and dry-run in Phase 8.

Replacing the Wikipedia sample with a real app should change these layers, in
this order, and only touch tests where the business behaviour itself differs:

1. **Runtime configuration** — `.env` / CI: `MAESTRO_APP_ID` per platform and
   environment, real `DEVICE_ID`, and secrets (`MAESTRO_TEST_USERNAME`, …) from
   the secret store. Never commit `.env`.
2. **SUT contract** — new `docs/sut-contract.md`: verified app IDs, journeys,
   overlays/prompts, reset strategy, test accounts.
3. **Selectors** — `.maestro/selectors/pages/*.js` and `selectors/components/*.js`:
   one file per real screen/component, grouped `id` / `text`. Ask the app team
   for accessibility identifiers and prefer `id`.
4. **Pages and components** — `.maestro/pages/<screen>/` and
   `.maestro/components/<name>/`: adapt actions to the real navigation,
   overlays and permissions.
5. **Common hooks** — `common/launch_clean.yaml` (reset strategy, permissions).
6. **Test data** — `.maestro/data/`: real, non-secret fixtures.
7. **Tests** — `.maestro/tests/<domain>/`: only where the journey differs.

Then run the smoke suite locally (`scripts/run_tests.sh --include-tags=smoke`)
before enabling CI.
