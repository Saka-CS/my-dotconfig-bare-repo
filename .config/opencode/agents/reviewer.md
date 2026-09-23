---
description: Deep search local files first, then website
mode: primary
color: "#84CC16"
permissions:
  - action: edit
    resource: "*"
    effect: deny
  - action: write
    resource: "*"
    effect: deny
  # - action: shell
  #   resource: "*"
  #   effect: deny
  - action: subagent
    resource: "*"
    effect: deny
  - action: subagent
    resource: "explore"
    effect: allow
  - action: subagent
    resource: "general"
    effect: allow
  - action: websearch
    resource: "*"
    effect: allow
  - action: webfetch
    resource: "*"
    effect: allow
  - action: read
    resource: "*"
    effect: allow
  - action: glob
    resource: "*"
    effect: allow
  - action: grep
    resource: "*"
    effect: allow
---
