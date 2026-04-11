#!/bin/bash
kubectl apply -f cpu-payload-template.spike.configmap.yaml
kubectl apply -f cpu-payload-env.spike.configmap.yaml
kubectl apply -f cpu-payload-script.spike.configmap.yaml
kubectl apply -f cpu-payload.spike.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/cpu-payload-spike cpu-payload-spike-manual-$(date +%Y%m%d%H%M%S)

# Wait for the CronJob to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f cpu-payload-template.spike.configmap.yaml
kubectl delete -f cpu-payload-env.spike.configmap.yaml
kubectl delete -f cpu-payload-script.spike.configmap.yaml
kubectl delete -f cpu-payload.spike.cron.yaml