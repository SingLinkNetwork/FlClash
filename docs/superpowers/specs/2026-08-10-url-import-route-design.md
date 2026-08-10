# URL Import Route Selection Design

## Goal

Let users explicitly choose proxy or direct routing when first importing a subscription URL, without changing the existing default or silently exposing a URL through a direct connection.

## Design

Replace the one-field URL input dialog used by the Profiles add sheet with a focused URL import dialog.  It contains the URL field and two labelled radio choices: `syncViaProxy` (selected by default) and `syncDirect`.  The dialog returns both URL and route choice.

`ProfilesAction.addProfileFormURL` gains an optional `useProxy` argument defaulting to true and passes it to `Profile.update`.  QR-code and external-link entry points retain that true default, preserving current behavior.

## Verification

Widget tests confirm the default proxy selection and selecting direct returns false.  An action-level regression confirms the new parameter's default remains true and is forwarded to profile update.  Full CI validates Flutter tests and all platform packages.
