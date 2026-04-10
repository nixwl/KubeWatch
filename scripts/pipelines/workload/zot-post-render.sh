#!/usr/bin/env bash
set -euo pipefail

yq eval-all -o=yaml '
  (select(
    (.kind == "Deployment" or .kind == "StatefulSet")
    and ((.metadata.namespace // "") == "zot")
    and (
      ((.metadata.labels."app.kubernetes.io/name" // "") == "zot")
      or ((.metadata.name // "") | test("(^|-)zot($|-)"))
    )
  ).spec.template.spec) |= (
    .nodeSelector = ((.nodeSelector // {}) + {"node-role":"worker"})
  )
' -