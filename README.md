# Omarchy Charge 100 Percent

![Charge Limit with the full-charge profile outlined](https://raw.githubusercontent.com/k7cfo/omarchy-charge-100-percent/6c3a3269b9975e9b25f154b5dc911971dc388396/preview.png)

A small Quickshell toolbar plugin for Omarchy. Choose **Travel · 100%** for runtime or **Everyday · 80%** for conservation.

- **100% stays selected after the battery fills.** Firmware handles top-ups using 99–100% start/stop thresholds.
- **Five continuous minutes unplugged restores Everyday**, normally 75–80%. Reconnect sooner and Travel survives; reconnect after expiry and Everyday remains.
- The current profile has a theme-accent outline; the battery fill shows its charge level.
- **↑ is hardware-confirmed:** AC connected, 99–100% thresholds, and Charging or Full (or Not charging at 100%). A selected limit alone is not proof of charging.
- **↓** confirms the conservation limit. `?` means operation is not confirmed; the chooser explains the state.
- No automatic popups, network requests, telemetry, or CPU power-profile changes.

## Requirements

- Omarchy with the plugin-capable Quickshell shell (`qs.Ui`, `qs.Commons`, UPower); tested on Omarchy 4.5.
- A Linux battery exposing **both** `charge_control_start_threshold` and `charge_control_end_threshold`, supporting 99–100% and 75–80% thresholds. Not every laptop does.
- Bash, coreutils, util-linux (`flock`, `setsid`), and sudo when using the privileged helper.

The first threshold-capable battery is controlled. Firmware may allow small fluctuations below 100%; the plugin does not force-discharge the battery when conservation is restored.

## Install

Plugins run unsandboxed inside your shell. Review the source before installation:

```bash
omarchy plugin add https://github.com/k7cfo/omarchy-charge-100-percent --enable
omarchy bar move io.github.k7cfo.charge-100-percent --before omarchy.power
```

### Explicit one-time permission setup

If the machine already has a compatible `/usr/local/sbin/set-battery-charge-thresholds`, the plugin reuses it. Otherwise review `scripts/install-helper` and `scripts/set-battery-charge-thresholds`, then explicitly run:

```bash
sudo ~/.config/omarchy/plugins/io.github.k7cfo.charge-100-percent/scripts/install-helper
```

**This is manual setup, not an automatic install hook.** It installs a root-owned helper and, unless an existing ThinkPad charge rule is present, `/etc/sudoers.d/omarchy-charge`. That rule permits only the helper, not an arbitrary shell. The helper validates numeric arguments and writes only the selected battery's start/stop thresholds. The installer initializes the cap to 75–80%. No packages, services, or autostart entries are installed.

Do not run this alongside competing charge policies (including older versions of Charge Limit). Disable or reconfigure those explicitly first. Existing timers or boot policies must use the same limits and must not cancel full charge when it reaches 99%.

## Use

| Input | Action |
|---|---|
| Click the battery | Open or close chooser |
| Click a profile | Apply it and show the hardware result |
| `1` / `2` | Full charge / conservation, top to bottom |
| `Esc` or click outside | Close without changing the profile |

The service reacts to UPower unplug events and reconciles the policy every 15 seconds. The indicator refreshes after actions, power-state changes, and periodically. Full charge is disabled when AC is not detected. The theme is followed live. English translations are bundled with Omarchy's language fallback mechanism.

The five-minute deadline is persisted under the shared policy lock using boot-relative time, including suspend time, rather than a wall clock that can jump. Shell restarts and the optional fallback timer share it. Reset occurs on the first policy check at/after expiry (normally within 15 seconds); fallback-only timing follows that timer's interval. A pending deadline from an earlier boot resets conservatively. Clicking Everyday takes effect immediately. This grace period is a convenience choice, not a scientifically established battery-health threshold.

`conserveEnd` in the widget settings defaults to 80; its start threshold is five points lower. If a separate fallback controller exists, keep its configuration aligned.

The shell must be running to observe unplug events immediately. An unplug/replug entirely while powered off or asleep cannot be detected by this plugin. It does not install a boot reset policy; an independently configured conservation-at-boot policy is recommended.

## Command line

From the plugin directory:

```bash
./scripts/charge-ctl status --json
./scripts/charge-ctl full
./scripts/charge-ctl conserve
./scripts/charge-ctl tick
```

`travel` is another name for `full`. Set `CHARGE_CONSERVE_END` for CLI calls when using a non-default cap. Hardware write failures are not reported as successful selections. Mutating calls share a lock; a disconnect during a full-charge write starts the same grace period. The service's `unplug` command records observed disconnections. Use this backend for any fallback timer; older controllers would bypass the grace period.

## Remove safely

Restore conservation before removal:

```bash
~/.config/omarchy/plugins/io.github.k7cfo.charge-100-percent/scripts/charge-ctl conserve
omarchy plugin remove io.github.k7cfo.charge-100-percent
```

The helper, sudoers rule, and state are intentionally not removed automatically: another charge controller may share them. If nothing else uses them, an administrator can remove `/etc/sudoers.d/omarchy-charge` and `/usr/local/sbin/set-battery-charge-thresholds`. Do not delete a pre-existing `thinkpad-smart-charge` rule or helper used by another tool. Check any timers or executable symlinks before deleting their target files.

State lives under `${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/smart-charge/`. Preserve it if another controller uses it. Removing the plugin while full charge is selected disables its unplug watcher; restore conservation first.

## Security and privacy

No credentials or network access are required. The plugin reads power-supply sysfs and writes its own mode state. Only the explicitly installed helper performs privileged threshold writes. The helper accepts percentages, not paths or commands. State updates are atomic and unchanged state is not rewritten. Reads are bounded and avoid following final-component symlinks; helper output is capped with a deadline. UI text is plain text, with shared button/tooltip text sanitized.

The marketplace's baseline should require manual review for the installer, privilege use, and sudoers modification. These capabilities are intentional and disclosed, not hidden. Marketplace listing is not a security audit, certification, or endorsement.

## Development checks

```bash
python3 tests/test_controller.py
node tests/test_model.js
omarchy plugin validate .
for script in scripts/*; do bash -n "$script"; done
node --check Model.js
```

Tests use isolated battery files, never real sysfs writes or sudo. They cover full-charge retention, unplug/replug, offline rejection, write failure, stale state, disconnect during a write, hardware status, indicator gating, and markup-safe display text. Node and Python are development-only dependencies.

Standalone `qmllint` needs Omarchy's shell exposed as a `qs` import. Current installed framework metadata produces warnings for dynamic theme properties and JavaScript maps assigned to Quickshell's `QVariantHash` environment; those paths have been checked at runtime. Warnings are not suppressed.

## Battery care: evidence and limits

The chooser starts with its battery-care explanation hidden. Click the battery-care button to expand or collapse it; reopening the chooser hides it again. It explains battery wear, the Everyday/Travel tradeoff, and the five-minute grace period. Research links stay here rather than in the panel. Practical advice:

- **Avoid heat**, especially while charging. Follow your laptop manufacturer's temperature limits; a cool, ventilated desk is preferable to a hot car or insulating bedding.
- **Avoid unnecessary extended time at full charge.** Everyday reduces time at a high state of charge; Travel deliberately trades that benefit for runtime. Charging to 100% for a trip is an intended use, not an immediate battery-damage event.
- **Do not deliberately drain to zero to “exercise” the battery.** For long-term storage, roughly half charge and a cool environment are recommended. A stored empty battery can become deeply discharged.
- Lowering the cap does not drain stored energy. The plugin never forces a discharge/recharge cycle, bypasses thermal protection, or controls USB-C negotiation. It cannot promise a lifespan improvement of a specific percentage.

Sources: [Apple — Maximizing Battery Life and Lifespan](https://www.apple.com/batteries/maximizing-performance/) explains reducing time at high charge, heat-related permanent capacity loss, and half-charged storage. [Apple — Lithium-ion batteries](https://www.apple.com/batteries/why-lithium-ion/) explains partial charging and cumulative charge cycles. These are manufacturer guidance for lithium-ion devices, not a controlled study of this ThinkPad or a universal 80% optimum. Laptop-specific firmware limits still govern charging.

## License

MIT. See [LICENSE](LICENSE).
