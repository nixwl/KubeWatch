#!/usr/bin/env bash
set -euo pipefail

yq ea '
  with(
    select(.kind=="DaemonSet" and .metadata.name=="chaosblade-tool");

    .spec.template.spec.volumes |= (
      ((. // []) + [
        {"name":"host-var-lib-rancher","hostPath":{"path":"/var/lib/rancher","type":"Directory"}}
      ]) | unique_by(.name)
    )
    |
    (.spec.template.spec.containers[] | select(.name=="chaosblade-tool") | .volumeMounts) |= (
      ((. // []) + [
        {"name":"host-var-lib-rancher","mountPath":"/var/lib/rancher","readOnly":false}
      ]) | unique_by(.name)
    )
  )
' -