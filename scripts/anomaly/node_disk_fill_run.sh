#!/usr/bin/env bash
kubectl apply -f disk-payload-template.fill.yaml
kubectl apply -f disk-payload-env.fill.configmap.yaml
kubectl apply -f disk-payload-script.fill.configmap.yaml
kubectl apply -f disk-payload.fill.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/disk-payload-fill disk-payload-fill-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f disk-payload-template.fill.yaml
kubectl delete -f disk-payload-env.fill.configmap.yaml
kubectl delete -f disk-payload-script.fill.configmap.yaml
kubectl delete -f disk-payload.fill.cron.yaml