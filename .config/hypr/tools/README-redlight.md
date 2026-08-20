# Red Monochrome Filter — Porting Guide (v2, fixes included)

Monochrome-red display filter for Hyprland, applied via the
`hyprland-ctm-control-v1` protocol as a 3×3 KMS plane CTM *below* the
compositor framebuffer. Result: red-on-monitor only, invisible to
screenshots (grim) and screencasts (OBS/PipeWire). Toggleable (keybind),
scheduled 19:00→06:30, survives Hyprland restarts, works across all connected
monitors.

This guide is the exact, working recipe from this machine, with the two bugs
found during bring-up already fixed:

1. The signal loop must use `wl_display_prepare_read` + `poll(250ms)` —
   **not** `wl_display_dispatch`. libwayland retries internally on EINTR, so
   with a blocking dispatch, SIGTERM never unblocks: `systemctl stop` hangs
   90 s → SIGKILL → `Restart=on-failure` restarts the filter and "off" doesn't
   stick.
2. The build must link **both** generated wayland-scanner files (header *and*
   private-code), otherwise you get
   `undefined reference to hyprland_ctm_control_manager_v1_interface`.
   Also, wayland-scanner ≥ 1.24 rejects the upstream XML (missing `summary`
   on the v2 `blocked` event) and takes an output-file argument instead of
   stdout — both worked around below.

## Mechanism (why CTM, not alternatives)

- **Gamma ramps** are per-channel curves; zeroing G/B forces pure blue/green
  pixels to black. Only a 3×3 matrix can mix channels (luma→red).
- **Screen shader** runs in Hyprland's render pass → baked into screencopy →
  OBS/grim would capture red.
- **KMS plane CTM** is applied after the compositor renders → physical display
  only.

The matrix (row-major, `mat0..mat8`, Rec. 709 luma):

```
out_R = 0.299*R + 0.587*G + 0.114*B
out_G = 0
out_B = 0
```

Pure blue → dark red (0.114), pure green → medium red (0.587), red stays red,
white → full red, black stays black. All values ≥ 0, so no `invalid_matrix`.

## Prerequisites (verify on the target machine)

- Arch Linux with **Hyprland ≥ 0.43** (dev machine: 0.56.0) + `wayland`,
  `gcc`, `pkg-config`.
- Outputs driven by **amdgpu or i915**. Does **NOT** work on NVIDIA
  proprietary driver (no standard plane CTM path).
- No `hyprsunset` running (it "blocks" our manager and wins priority).

Preflight — run and note the values (you'll plug them into the unit file):

```bash
echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"
id -u                     # -> UID for XDG_RUNTIME_DIR path
pkg-config --exists wayland-client && echo "wayland-client OK"
hyprctl -v | head -1      # confirm >= 0.43
pacman -Q hyprland wayland gcc pkg-config
pgrep -a hyprsunset       # must print nothing
```

If `WAYLAND_DISPLAY` is empty in your shell, run it inside the running session
(e.g. `uwsm app -- bash -lc 'echo $WAYLAND_DISPLAY'`).

## Step 1 — Install the protocol package

```bash
sudo pacman -S hyprland-protocols
```

## Step 2 — Layout

```bash
mkdir -p ~/.config/hypr/tools
# everything lives in: ~/.config/hypr/tools/, ~/.local/bin/, ~/.config/systemd/user/
```

## Step 3 — Generate the Wayland bindings (with DTD workaround)

Copy the XML, patch it, then generate both files.

```bash
cp /usr/share/hyprland-protocols/protocols/hyprland-ctm-control-v1.xml \
   ~/.config/hypr/tools/hyprland-ctm-control-v1.xml
```

Patch the copied XML — the `blocked` event must change from:

```xml
    <event name="blocked" version="2">
      <description>
```

to:

```xml
    <event name="blocked" version="2">
      <description summary="the manager is blocked by another CTM manager">
```

Then generate **both** files (the second one is required to link):

```bash
wayland-scanner client-header ~/.config/hypr/tools/hyprland-ctm-control-v1.xml \
  ~/.config/hypr/tools/hyprland-ctm-control-v1-client.h
wayland-scanner private-code ~/.config/hypr/tools/hyprland-ctm-control-v1.xml \
  ~/.config/hypr/tools/hyprland-ctm-control-v1-protocol.c
```

A DTD warning may still print on the client-header step — that's fine. Verify
the header is non-empty (`wc -l` should be ~223).

## Step 4 — `~/.config/hypr/tools/hypr-ctm-red.c` (verbatim, fixed)

```c
/*
 * hypr-ctm-red.c
 *
 * Monochrome (luma -> red) display filter for Hyprland.
 *
 * Uses the hyprland-ctm-control-v1 Wayland protocol (interface
 * hyprland_ctm_control_manager_v1, version 2) to set a 3x3 color transform
 * matrix on every output. The matrix is applied by the GPU at the KMS plane
 * level AFTER the compositor renders, so:
 *   - it is visible on the physical display(s), AND
 *   - it is invisible to screenshots (grim) and screencasts (OBS/PipeWire),
 *     which capture the pre-CTM framebuffer.
 *
 * Long-running foreground process managed by systemd (redlight.filter.service,
 * Type=simple). It must stay connected to hold the manager; when it exits the
 * compositor resets all outputs to the identity matrix (filter turns off).
 *
 * Exit codes (contract with Restart=on-failure / RestartPreventExitStatus=2):
 *   0  clean shutdown after SIGTERM (systemctl stop)            -> no restart
 *   1  Wayland/compositor error (Hyprland restarted, EPIPE)     -> restart
 *   2  blocked by another CTM manager (hyprsunset has priority) -> no restart
 */

#define _GNU_SOURCE
#include <errno.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <wayland-client.h>
#include "hyprland-ctm-control-v1-client.h"

/* 3x3 row-major CTM. Rec. 709 luminance drives the red channel; green and blue
 * channels are zeroed. Result: every non-black pixel renders as a shade of red;
 * pure blue/green become dark/medium red instead of black. */
static const double MATRIX[9] = {
    0.299, 0.587, 0.114, /* out_R = 0.299*R + 0.587*G + 0.114*B (luma) */
    0.000, 0.000, 0.000, /* out_G = 0 */
    0.000, 0.000, 0.000, /* out_B = 0 */
};

static struct wl_display*                            g_display = NULL;
static struct hyprland_ctm_control_manager_v1*        g_manager = NULL;
static volatile sig_atomic_t                         g_running = 1;
static volatile sig_atomic_t                         g_blocked = 0;

struct output_info {
    struct wl_output* output;
    struct wl_list    link;
};
static struct wl_list g_outputs;

static void on_signal(int sig) {
    (void)sig;
    g_running = 0;
}

static void manager_blocked(void* data,
                            struct hyprland_ctm_control_manager_v1* manager) {
    (void)data;
    (void)manager;
    g_blocked = 1;
}

static const struct hyprland_ctm_control_manager_v1_listener manager_listener = {
    .blocked = manager_blocked,
};

static void apply_all(void) {
    struct output_info* info;
    wl_list_for_each(info, &g_outputs, link) {
        hyprland_ctm_control_manager_v1_set_ctm_for_output(
            g_manager, info->output,
            wl_fixed_from_double(MATRIX[0]), wl_fixed_from_double(MATRIX[1]),
            wl_fixed_from_double(MATRIX[2]), wl_fixed_from_double(MATRIX[3]),
            wl_fixed_from_double(MATRIX[4]), wl_fixed_from_double(MATRIX[5]),
            wl_fixed_from_double(MATRIX[6]), wl_fixed_from_double(MATRIX[7]),
            wl_fixed_from_double(MATRIX[8]));
    }
    hyprland_ctm_control_manager_v1_commit(g_manager);
}

static void registry_global(void* data, struct wl_registry* registry,
                            uint32_t name, const char* interface,
                            uint32_t version) {
    (void)data;
    if (strcmp(interface, wl_output_interface.name) == 0) {
        struct output_info* info = calloc(1, sizeof *info);
        if (!info)
            return;
        info->output = wl_registry_bind(registry, name, &wl_output_interface, 1);
        wl_list_insert(&g_outputs, &info->link);
        if (g_manager) {
            /* Monitor plugged in at runtime: apply immediately. */
            apply_all();
            wl_display_flush(g_display);
        }
    } else if (strcmp(interface, hyprland_ctm_control_manager_v1_interface.name) == 0) {
        /* Bind at min(offered, 2): the "blocked" event is v2-only, but the
         * shared request message layout is identical at v1, so this is safe on
         * older Hyprland (0.43-0.46). No-op on >= 0.47 which offers v2. */
        uint32_t bind_ver = version > 2 ? 2 : version;
        g_manager = wl_registry_bind(registry, name,
                                     &hyprland_ctm_control_manager_v1_interface, bind_ver);
        hyprland_ctm_control_manager_v1_add_listener(g_manager, &manager_listener, NULL);
    }
}

static void registry_remove(void* data, struct wl_registry* registry,
                            uint32_t name) {
    /* Deliberately empty: a stale wl_output passed to set_ctm_for_output is
     * silently ignored by Hyprland, so removals don't need tracking. */
    (void)data;
    (void)registry;
    (void)name;
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_remove,
};

static void cleanup(void) {
    if (g_manager)
        hyprland_ctm_control_manager_v1_destroy(g_manager);
    if (g_display)
        wl_display_disconnect(g_display);
}

int main(void) {
    struct sigaction sa = {0};
    sa.sa_handler = on_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0; /* NO SA_RESTART: signals interrupt poll() below */
    sigaction(SIGTERM, &sa, NULL);
    sigaction(SIGINT,  &sa, NULL);
    signal(SIGPIPE, SIG_IGN);

    g_display = wl_display_connect(NULL);
    if (!g_display) {
        fprintf(stderr, "hypr-ctm-red: cannot connect to Wayland "
                        "(check WAYLAND_DISPLAY and XDG_RUNTIME_DIR)\n");
        return 1;
    }

    wl_list_init(&g_outputs);
    struct wl_registry* registry = wl_display_get_registry(g_display);
    wl_registry_add_listener(registry, &registry_listener, NULL);

    if (wl_display_roundtrip(g_display) < 0) {
        fprintf(stderr, "hypr-ctm-red: registry roundtrip failed\n");
        cleanup();
        return 1;
    }

    if (!g_manager) {
        fprintf(stderr, "hypr-ctm-red: compositor does not offer "
                        "hyprland_ctm_control_manager_v1\n");
        cleanup();
        return 1;
    }

    if (g_blocked) {
        fprintf(stderr, "hypr-ctm-red: blocked by another CTM manager "
                        "(e.g. hyprsunset) which has priority; exiting\n");
        cleanup();
        return 2;
    }

    apply_all();
    if (wl_display_flush(g_display) < 0) {
        fprintf(stderr, "hypr-ctm-red: failed to flush Wayland connection\n");
        cleanup();
        return 1;
    }

    /* Hold the connection. SIGTERM (systemctl stop) sets g_running = 0 and
     * interrupts poll() (SA_RESTART disabled), so the loop exits cleanly and
     * the process returns 0. The 250ms poll timeout additionally lets us
     * notice g_running even when the compositor is completely idle. */
    while (g_running) {
        if (wl_display_prepare_read(g_display) == -1) {
            /* events already queued: dispatch them now */
            if (wl_display_dispatch_pending(g_display) < 0)
                break;
            continue;
        }

        struct pollfd pfd = {.fd = wl_display_get_fd(g_display),
                             .events = POLLIN};
        int ret = poll(&pfd, 1, 250);
        if (ret == -1) {
            wl_display_cancel_read(g_display);
            if (errno != EINTR) {
                fprintf(stderr, "hypr-ctm-red: poll failed\n");
                break;
            }
            continue; /* signal handled; re-check g_running */
        }
        if (ret == 0) {
            /* idle timeout: nothing to read, re-check g_running */
            wl_display_cancel_read(g_display);
            continue;
        }
        if (wl_display_read_events(g_display) < 0) {
            fprintf(stderr, "hypr-ctm-red: Wayland connection lost "
                            "(compositor exited?)\n");
            break; /* exit 1 -> systemd restarts us */
        }
        if (wl_display_dispatch_pending(g_display) < 0) {
            fprintf(stderr, "hypr-ctm-red: Wayland connection lost "
                            "(compositor exited?)\n");
            break; /* exit 1 -> systemd restarts us */
        }
    }

    cleanup();
    return g_running ? 1 : 0;
}
```

## Step 5 — Build (must link BOTH generated files)

```bash
gcc -O2 -Wall -Wextra -o ~/.local/bin/hypr-ctm-red \
  ~/.config/hypr/tools/hypr-ctm-red.c \
  ~/.config/hypr/tools/hyprland-ctm-control-v1-protocol.c \
  $(pkg-config --cflags --libs wayland-client)
```

Omitting the `-protocol.c` file gives
`undefined reference to hyprland_ctm_control_manager_v1_interface`. Build must
finish with no errors/warnings before continuing.

## Step 6 — `~/.local/bin/redlightctl` (verbatim)

```bash
#!/usr/bin/env bash
case "${1:-toggle}" in
  on)     systemctl --user start  redlight.filter.service ;;
  off)    systemctl --user stop   redlight.filter.service ;;
  toggle) if systemctl --user is-active --quiet redlight.filter.service; then
            systemctl --user stop redlight.filter.service
          else
            systemctl --user start redlight.filter.service
          fi ;;
  auto)   h=$(date +%H%M)
          # window is [19:00, 06:30); boundary semantics: 19:00 -> on, 06:30 -> off
          if (( 10#$h >= 1900 )) || (( 10#$h < 630 )); then
            systemctl --user start redlight.filter.service
          else
            systemctl --user stop redlight.filter.service
          fi ;;
  status) if systemctl --user is-active --quiet redlight.filter.service; then
            echo "on"
          else
            echo "off"
          fi ;;
  *)      echo "usage: redlightctl {on|off|toggle|auto|status}" >&2; exit 2 ;;
esac
```

```bash
chmod +x ~/.local/bin/redlightctl
```

Notes:
- `10#$h` forces base-10 on `date +%H%M` output (0630 would otherwise parse as
  octal-ish); comparison literals are written without leading zeros (630, 1900).
- `systemctl --user start` is idempotent, so `auto` is safe to run repeatedly.

## Step 7 — systemd units (plug in YOUR env values from Step 0)

`~/.config/systemd/user/redlight.filter.service` — set `WAYLAND_DISPLAY` and
the UID in `XDG_RUNTIME_DIR` to your values:

```ini
[Unit]
Description=Red monochrome filter (KMS CTM, invisible to OBS/screenshots)

[Service]
Type=simple
Environment=WAYLAND_DISPLAY=wayland-1
Environment=XDG_RUNTIME_DIR=/run/user/1000
ExecStart=%h/.local/bin/hypr-ctm-red
Restart=on-failure
RestartSec=2
RestartPreventExitStatus=2
```

- `Restart=on-failure` → auto-reconnect after a Hyprland restart (process exits
  1 when the socket dies).
- `RestartPreventExitStatus=2` → a "blocked by hyprsunset" exit (code 2) does
  not restart-loop.

`~/.config/systemd/user/redlight.timer`:

```ini
[Unit]
Description=Red light filter schedule (on 19:00, off 06:30)

[Timer]
OnCalendar=*-*-* 06:30:00
OnCalendar=*-*-* 19:00:00
# No Persistent=true: a boot that happens during the day must not force the
# filter on retroactively.

[Install]
WantedBy=timers.target
```

`~/.config/systemd/user/redlight.service` (no `[Install]`; pulled in by the
timer):

```ini
[Unit]
Description=Apply red light filter according to current time

[Service]
Type=oneshot
ExecStart=%h/.local/bin/redlightctl auto
```

## Step 8 — Hyprland config integration

Adapt file names to your Hyprland layout (vanilla setups can put all three in
`~/.config/hypr/hyprland.conf`):

1. **Keybind** (add to your bindings file):
   `bindd = SUPER, R, Red light toggle, exec, redlightctl toggle`
2. **Autostart** (add an `exec-once`):
   `exec-once = redlightctl auto`
3. **Fullscreen persistence** (append to the config):
   `render:non_shader_cm_interop = 1`

Then: `hyprctl reload`

## Step 9 — Remove an old hyprshade setup (only if it exists)

```bash
systemctl --user disable --now hyprshade.timer 2>/dev/null
rm -f ~/.config/systemd/user/hyprshade.service ~/.config/systemd/user/hyprshade.timer
rm -f ~/.config/hypr/hyprshade.toml
rm -rf ~/.config/hypr/shaders
pipx uninstall hyprshade 2>/dev/null || true
hyprctl keyword decoration:screen_shader ""
```

## Step 10 — Enable

```bash
systemctl --user daemon-reload
systemctl --user enable --now redlight.timer
```

`redlight.filter.service` and `redlight.service` do not need to be enabled —
they are started on demand (timer, toggle, autostart).

## Step 11 — Verification

**A. Config clean:**

```bash
hyprctl configerrors                          # empty
hyprctl getoption render:non_shader_cm_interop   # int: 1
hyprctl getoption decoration:screen_shader       # [[EMPTY]]
pgrep -a hyprsunset                           # nothing
```

**B. On/off:**

```bash
redlightctl status            # off
redlightctl on
redlightctl status            # on
pgrep -a hypr-ctm-red         # one process
```

**C. Visual:** screen goes red monochrome (blue→dark red, green→medium red,
white→full red, black stays black).

**D. Capture unaffected (the reliable test).** The naive "byte-identical grim"
test is flaky on any animating UI. Use the analysis method instead —
`maxG`/`maxB` of the "on" capture must stay high (capture is NOT red-tinted)
and the off/on diff must be tiny and localized:

```bash
redlightctl off && grim /tmp/off.png
redlightctl on  && grim /tmp/on.png
magick /tmp/on.png -format "maxG %[fx:maxima.g] maxB %[fx:maxima.b]\n" info:
# expect maxG ~0.8, maxB ~0.96 (full color -> no leak into capture)
magick /tmp/off.png /tmp/on.png -compose difference -composite -threshold 1 \
  -format "%[fx:mean*w*h] differing px\n" info:
# expect <<1% of pixels, all from cursor/clock movement
```

(Requires ImageMagick. The dev machine measured 786/2,073,600 px differing —
a cursor/UI animation — with full G/B in the "on" capture.)

**E. OBS:** record ~10 s with the filter on; playback must show normal colors.

**F. Fullscreen:** open a fullscreen window (video/game); red must persist
(`render:non_shader_cm_interop = 1`).

**G. Toggle + stop speed (regression test for the signal bug).** `off` must
return in < 2 s, and no restart may follow:

```bash
t0=$SECONDS; redlightctl off; echo "$((SECONDS-t0))s"; sleep 1; pgrep hypr-ctm-red || echo "gone"
```

**H. Schedule:**

```bash
systemctl --user list-timers redlight.timer   # next elapse 19:00
systemctl --user start redlight.service       # force-run the scheduler
redlightctl status                            # matches the current time window
# boundary logic: 0629->on, 0630->off, 1859->off, 1900->on, 1901->on
```

**I. Crash resilience:**

```bash
kill -9 $(pgrep hypr-ctm-red)     # auto-restarted and re-applied within ~2 s
```

**J. Hotplug:** plug a second monitor → it turns red immediately (registry
path).

## Troubleshooting

- **"cannot connect to Wayland" in the journal** — wrong
  `WAYLAND_DISPLAY`/`XDG_RUNTIME_DIR` in the unit (Step 0 values), or Hyprland
  not running.
- **Process exits 2 / no restart loop** — another CTM manager (hyprsunset)
  holds priority. Stop it, then `redlightctl on`.
- **Stop hangs 90 s + SIGKILL** — you replaced the signal loop; use the Step 4
  code verbatim.
- **Undefined reference at link** — missing
  `hyprland-ctm-control-v1-protocol.c` in the build (Step 5).
- **Empty generated header** — XML not patched (Step 3).
- **Screen not red but process runs** — GPU is NVIDIA proprietary
  (unsupported) or Hyprland < 0.43.
- **Filter gone after DPMS sleep/wake** — untested edge; re-apply with
  `redlightctl toggle` or `systemctl --user restart redlight.filter.service`.
- **Hardware capture device** recording the physical output will see red —
  expected and unavoidable.
- **Manual override** persists until the next timer fire (06:30 or 19:00) —
  same behavior as the old hyprshade setup.

## Rollback

```bash
systemctl --user disable --now redlight.timer
systemctl --user stop redlight.filter.service
rm -f ~/.config/systemd/user/redlight.timer ~/.config/systemd/user/redlight.service \
      ~/.config/systemd/user/redlight.filter.service
rm -f ~/.local/bin/redlightctl ~/.local/bin/hypr-ctm-red
rm -rf ~/.config/hypr/tools
systemctl --user daemon-reload
# remove: bindd SUPER,R / exec-once redlightctl auto / render:non_shader_cm_interop=1
```

## Customization knobs

- **Schedule**: edit `redlightctl` (auto window) and `redlight.timer`
  (calendar times) together.
- **Keybind**: change the `bindd` line.
- **Color**: replace `MATRIX` — any 3×3 row-major. Examples:
  - pure green: `{0,1,0, 0,0,0, 0,0,0}`
  - amber: `{0.6,0.4,0, 0,0,0, 0,0,0}`
  - Values must be ≥ 0 to avoid the `invalid_matrix` error.

## Portable migration tip

The whole setup is the contents of three directories:
- `~/.config/hypr/tools/` (source, patched XML, generated header + code)
- `~/.local/bin/hypr-ctm-red` and `~/.local/bin/redlightctl`
- `~/.config/systemd/user/redlight.*`

Copy them to a new machine, then fix only the two `Environment=` lines in
`redlight.filter.service` and the Hyprland config paths in Step 8.
