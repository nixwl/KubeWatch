#!/bin/bash
kubectl apply -f mem-payload-template.spike.yaml
kubectl apply -f mem-payload-env.spike.configmap.yaml
kubectl apply -f mem-payload-script.spike.configmap.yaml
kubectl apply -f mem-payload.spike.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/mem-payload-spike mem-payload-spike-manual-$(date +%Y%m%d%H%M%S)

# Wait for the CronJob to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f mem-payload-template.spike.yaml
kubectl delete -f mem-payload-env.spike.configmap.yaml
kubectl delete -f mem-payload-script.spike.configmap.yaml
kubectl delete -f mem-payload.spike.cron.yaml