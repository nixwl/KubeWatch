#!/usr/bin/env bash
kubectl apply -f net-payload-template.loss.yaml
kubectl apply -f net-payload-env.loss.configmap.yaml
kubectl apply -f net-payload-script.loss.configmap.yaml
kubectl apply -f net-payload-loss.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/net-payload-loss net-payload-loss-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Revert
kubectl delete -f net-payload-template.loss.yaml
kubectl delete -f net-payload-env.loss.configmap.yaml
kubectl delete -f net-payload-script.loss.configmap.yaml
kubectl delete -f net-payload-loss.cron.yaml