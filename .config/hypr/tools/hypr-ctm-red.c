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
    (void)version;
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
        g_manager = wl_registry_bind(registry, name,
                                     &hyprland_ctm_control_manager_v1_interface, 2);
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
    sa.sa_flags = 0; /* NO SA_RESTART: signals interrupt the blocking dispatch */
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
     * interrupts poll() (SA_RESTART is disabled), so the loop exits cleanly
     * and the process returns 0. The 250ms poll timeout additionally lets us
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
