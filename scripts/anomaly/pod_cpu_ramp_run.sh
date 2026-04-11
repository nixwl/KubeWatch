#!/usr/bin/env bash
kubectl apply -f cpu-payload-template.pod.ramp.yaml
kubectl apply -f cpu-payload-env.pod.ramp.configmap.yaml
kubectl apply -f cpu-payload-script.pod.ramp.configmap.yaml
kubectl apply -f cpu-payload.pod.ramp.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/cpu-payload-pod-ramp cpu-payload-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f cpu-payload-template.pod.ramp.yaml
kubectl delete -f cpu-payload-env.pod.ramp.configmap.yaml
kubectl delete -f cpu-payload-script.pod.ramp.configmap.yaml
kubectl delete -f cpu-payload.pod.ramp.cron.yaml