## Summary

Explain the change and why it’s needed.

## Screenshots / Video

_If UI_

## How to test
- Open Xcode **16.x**
- Select scheme **Kuna**
- Run unit tests (⌘U) or: `xcodebuild -scheme Kuna -configuration Debug -destination "platform=iOS Simulator,name=iPhone 16 Pro" test`

## Checklist

- [ ] Builds locally in Xcode
- [ ] Unit tests pass
- [ ] No new SwiftLint violations (`swiftlint --strict`)
- [ ] Localized strings updated (if user-visible text changed)
- [ ] Linked issues updated (e.g., `Closes #123`)

## Linked issues

Closes #
