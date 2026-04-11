#!/bin/bash
kubectl apply -f mem-payload-template.high.yaml
kubectl apply -f mem-payload-env.high.configmap.yaml
kubectl apply -f mem-payload-script.high.configmap.yaml
kubectl apply -f mem-payload.high.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/mem-payload-high mem-payload-high-manual-$(date +%Y%m%d%H%M%S)

# Wait for the CronJob to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f mem-payload-template.high.yaml
kubectl delete -f mem-payload-env.high.configmap.yaml
kubectl delete -f mem-payload-script.high.configmap.yaml
kubectl delete -f mem-payload.high.cron.yaml