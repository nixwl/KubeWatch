#!/usr/bin/env bash
kubectl apply -f net-payload-template.delay.yaml
kubectl apply -f net-payload-env.delay.configmap.yaml
kubectl apply -f net-payload-script.delay.configmap.yaml
kubectl apply -f net-payload.delay.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/net-payload-delay net-payload-delay-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f net-payload-template.delay.yaml
kubectl delete -f net-payload-env.delay.configmap.yaml
kubectl delete -f net-payload-script.delay.configmap.yaml
kubectl delete -f net-payload.delay.cron.yaml