# Public Contributor Checklist

Use this checklist before adding new code to the public repository.

## Shell changes
- Does the change touch `app.dart`, `main.dart`, `settings_screen.dart`, `main_home_page.dart`, or `app_drawer.dart`?
- If yes, confirm the change does not add commercial branching logic.
- If the feature is private, expose it through the bundle/provider seam instead of hardcoding it into the shell.

## Settings changes
- If a new settings entry is private, add it through `SettingsEntryContribution` from the bundle.
- Do not make `settings_screen.dart` decide capability or entitlement visibility.

## Shared state changes
- Do not add subscription, receipt, entitlement, billing, pricing, or plan state to public shared models.
- Avoid putting commercial state into preferences, session, account, or update config.

## File placement
- Put public runtime code under `memos_flutter_app/`.
- Do not recreate root-level runtime files under `lib/`.
- Do not add private repository overlays or private package directories to this public repository.

## Diagnostics
- `AccessDecision.source` is for logging and diagnostics only.
- Never branch on `AccessDecision.source`.

## Before merging
- Run the public guardrail script.
- Run focused tests for the touched boundary area.
- If the change is architecture-related, update the relevant docs in `docs/`.
