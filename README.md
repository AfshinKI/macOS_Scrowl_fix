# Scroll Fix for macOS

A small native Swift menu bar utility for independent mouse and trackpad scroll reversal. Requires macOS 13+ and Apple's Command Line Tools. No package dependencies, telemetry, or network access at runtime.

## Run with one command

```bash
git clone git@github.com:AfshinKI/macOS_Scrowl_fix.git "$HOME/macOS_Scrowl_fix" && bash "$HOME/macOS_Scrowl_fix/scripts/run.sh"
```

The command builds for your Mac's architecture, signs locally, installs to `~/Applications/Scroll Fix.app`, and launches it. GitHub SSH access is required for this clone URL. If Command Line Tools are missing, run `xcode-select --install`, finish Apple's installer, then rerun the script.

For subsequent launches, use `open "$HOME/Applications/Scroll Fix.app"`. To rebuild after pulling changes, run `bash "$HOME/macOS_Scrowl_fix/scripts/run.sh"`.

## First launch

1. Quit Scroll Reverser and other utilities that change scrolling; otherwise they may reverse each other's changes.
2. In System Settings → Privacy & Security → Accessibility, enable **Scroll Fix**. If absent, click **+** and select `~/Applications/Scroll Fix.app` (Command-Shift-G lets you enter that path).
3. Click the up/down arrow icon in the menu bar. Its status should become **Active** automatically after permission is granted.

The default reverses vertical mouse-wheel scrolling and preserves the trackpad. Reversal is relative to your existing macOS scrolling setting.

## Options

- Enable / pause all changes.
- Reverse mouse and reverse trackpad independently.
- Choose vertical, horizontal, or both axes. These axes apply to both selected device categories.
- Mouse speed: 0.5× to 3×; 1× preserves the input magnitude. Speed applies even if mouse reversal is disabled. Low-resolution wheels may round fractional speeds.
- Treat unphased smooth scrolling as mouse: useful for smooth-wheel mice that macOS reports as continuous input.
- Launch at login using macOS's native login-item service. macOS may request approval in Login Items.
- Open Accessibility settings, restart the listener, and view help.

Settings persist across launches. The event tap handles only scrolling, modifies all three representations of each selected axis, and recovers after timeouts and wake. It does not monitor keys.

## Device detection limits

Public scroll-event APIs do not provide a dependable physical mouse/trackpad identity. This app uses continuous-event flags plus gesture/momentum phases. Discrete wheels count as mice; continuous scrolling counts as trackpad unless the smooth-mouse override is enabled. Phase-bearing input always counts as trackpad. Some Magic Mouse drivers, remote sessions, or accessibility tools can blur these categories. This is category-level control, not per-hardware-device configuration.

This is an independent implementation inspired by Scroll Reverser's controls, not a fork. It does not implement every Scroll Reverser feature, including tablet classification or fixed wheel-step sizing.

## Troubleshooting

- **Permission needed:** enable Accessibility for the installed app. Locally signed rebuilt binaries may need to be removed from the Accessibility list and added again.
- **Listener unavailable:** check Accessibility and use Restart scroll listener. If the permission entry is stale, remove/re-add it and reopen the app.
- **No effect or double reversal:** quit other scroll modifiers; check Enable Scroll Fix, Reverse mouse, and the vertical/horizontal axes.
- **Smooth mouse unchanged:** try the smooth-scrolling override. Phase-bearing mouse events cannot always be separated from trackpad events with this detector.
- **Login setting needs approval:** approve Scroll Fix in System Settings → General → Login Items.

## Development

```bash
./scripts/test.sh
./scripts/run.sh
```

`test.sh` runs policy regression checks and type-checks the complete AppKit app. The application is built directly with `swiftc`; Xcode IDE is not required. The installer uses ad-hoc signing, not Apple notarization. Test real hardware, Accessibility permission flow, sleep/wake, and login behavior on your Mac before relying on it daily.

To uninstall: disable Launch at login, quit the app, then remove `~/Applications/Scroll Fix.app`. To remove saved preferences, run `defaults delete com.afshinki.scrollfix`.
