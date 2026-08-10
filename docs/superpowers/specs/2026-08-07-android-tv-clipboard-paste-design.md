# Android TV Subscription Clipboard Paste Design

## Source and confirmed symptom

This design addresses upstream [FlClash#2196](https://github.com/chen08209/FlClash/issues/2196). The report says the Android TV build cannot paste a copied subscription URL into the add-profile form, while the same action works in Clash. The report contains no log, so this design targets the confirmed input-path limitation only.

The current add-profile URL flow uses `InputDialog` in `lib/views/profiles/add.dart`. `InputDialog` exposes a `TextFormField`, but it has no explicit clipboard action. On a TV, the standard long-press/context-menu paste operation may be unavailable or impractical with a remote control.

## Goal

Give the URL input dialog a visible and keyboard/remote-focusable paste action that reads the plain-text clipboard and inserts a non-empty value into the existing field.

## Non-goals

- Do not add Android permissions or native Android code.
- Do not change URL validation, profile creation, subscription fetching, or clipboard contents.
- Do not claim that every Android TV input method is fixed; the fix covers the application-controlled URL input path.

## Chosen approach

Add a localized paste icon button as the URL text field's `suffixIcon` in the reusable `InputDialog`. The button is available on every platform so the behavior stays consistent and does not require platform detection.

When activated:

1. Read `Clipboard.kTextPlain`.
2. If the clipboard has no text or only an empty string, leave the current field unchanged.
3. Otherwise replace the field contents with the clipboard text and place the caret at the end.
4. Keep the existing validator and Submit action unchanged.

The existing `paste` localization and Material `content_paste` icon are reused. A stable widget key makes the behavior directly testable without depending on visual text.

## Verification

- Widget tests mock the Flutter platform clipboard channel and cover successful insertion and empty-clipboard preservation.
- The full Flutter test suite and analyzer must pass locally.
- The existing GitHub Actions workflow must pass its Dart, Linux, Android, macOS, and Windows jobs for the fix commit. This proves cross-platform compilation and automated behavior; it does not pretend to be physical Android TV remote testing.

## Acceptance criteria

- A remote/keyboard-focusable paste button is present in `InputDialog`.
- A copied plain-text URL appears in the field after activating the button.
- Empty clipboard data does not erase existing text.
- Existing validation and submission behavior remains unchanged.
- The fix is documented in the downstream issue corresponding to upstream #2196 only after local tests and all five CI jobs succeed.

