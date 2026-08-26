# Home Row Mods Research Plan

## Goal

Fix home row mods in kanata config at `/home/saka/.config/kanata/config.kbd`

## Current Problem

When typing capital letters (e.g., pressing `f` for Shift then `h`), the modifier doesn't activate in time.
Result: `fh` instead of `H`. The user starts a new word, so `tap-hold-require-prior-idle 150` is NOT the cause.

## What the user now understands

- `tap-hold` — hold only activates after full timeout; too slow for capitalization
- `tap-hold-press` — activates hold on any key press; too aggressive for fast typing
- `tap-hold-release` — activates hold on press+release; better but still doesn't solve single-letter capitalization

## What to research

The `key-timing` approach the kanata community recommends, specifically from discussions #1455 and #1656.

---

## Search plan

### 1. Read discussion #1455 — "Skip home row mods while typing"

- URL: https://github.com/jtroo/kanata/discussions/1455
- Find the `key-timing` + `switch` template that skips home row mods during fast typing
- Look for the `homerowmod` template:
  ```
  (deftemplate homerowmod (timeouthold char mod)
    (switch
      ((key-timing 3 less-than 140)) $char break
      () (tap-hold-release 0 $timeouthold $char $mod) break
    )
  )
  ```
- Understand what `key-timing 3 less-than 140` means (check if 3 key presses happened within 140ms)

### 2. Read discussion #1656 — "Avoid unintended home row mod activation - Endgame"

- URL: https://github.com/jtroo/kanata/discussions/1656
- Find the latest "endgame" config (around 2025-09-13)
- Understand the `homerowmod` template and the `homerowmodfiltered` template
- Look for how `hold-for-duration` is used instead of `on-idle`
- Find how space triggers exit from fast-typing layer

### 3. Read the kanata sample config — home-row-mod-advanced.kbd

- URL: https://github.com/jtroo/kanata/blob/main/cfg_samples/home-row-mod-advanced.kbd
- Understand the `tap-hold-release-keys` approach with left-hand/right-hand key lists
- Understand the `nomods` layer and `on-idle-fakekey` mechanism

### 4. Read the kanata docs on `key-timing`

- URL: https://jtroo.github.io/config.html
- Search for `key-timing` in the page
- Understand: what does `key-timing N less-than M` check?
  - N = number of recent key presses
  - M = time window in ms

### 5. Read the kanata docs on `switch` action

- Same URL as above
- Search for the `switch` action documentation
- Understand the syntax: `(switch ((condition)) action break () fallback break)`

### 6. Synthesize a recommendation

For the user's config that:
- Fixes capitalization (the "H becomes fh" problem)
- Doesn't break fast typing (no accidental modifiers)
- Is as simple as possible (user is a beginner)
- Works with their existing `tap-hold-require-prior-idle 150` setting

---

## Key questions to answer

1. How does `key-timing N less-than M` work exactly? What do N and M mean?
2. Can `key-timing` + `switch` + `tap-hold-release` solve the capitalization problem?
3. What's the simplest implementation for a beginner?
4. Does this approach conflict with `tap-hold-require-prior-idle`?
5. What are the recommended timeout values for a moderate-speed typist?

---

## Current config for reference

```lisp
(defvar
  tap-timeout  200
  hold-timeout 200
  prior-idle   150
)

(defcfg
  linux-dev-names-include (
    "AT Translated Set 2 keyboard"
    "BY Tech Gaming Keyboard"
  )
  linux-continue-if-no-devs-found yes
  log-layer-changes no
  process-unmapped-keys yes
  concurrent-tap-hold yes
  tap-hold-require-prior-idle 150
)

(defalias
  a    (tap-hold $tap-timeout $hold-timeout a    lmet)
  s    (tap-hold $tap-timeout $hold-timeout s    lalt)
  d    (tap-hold $tap-timeout $hold-timeout d    lctl)
  f    (tap-hold $tap-timeout $hold-timeout f    lsft)
  j    (tap-hold $tap-timeout $hold-timeout j    rsft)
  k    (tap-hold $tap-timeout $hold-timeout k    rctl)
  l    (tap-hold $tap-timeout $hold-timeout l    ralt)
  scln (tap-hold $tap-timeout $hold-timeout scln rmet)
)
```
