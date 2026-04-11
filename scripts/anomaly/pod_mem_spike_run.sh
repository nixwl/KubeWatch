#!/usr/bin/env bash
kubectl apply -f mem-payload-template.pod.spike.yaml
kubectl apply -f mem-payload-env.pod.spike.configmap.yaml
kubectl apply -f mem-payload-script.pod.spike.configmap.yaml
kubectl apply -f mem-payload.pod.spike.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/mem-payload-pod-spike mem-payload-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Roll back
kubectl delete -f mem-payload-template.pod.spike.yaml
kubectl delete -f mem-payload-env.pod.spike.configmap.yaml
kubectl delete -f mem-payload-script.pod.spike.configmap.yaml
kubectl delete -f mem-payload.pod.spike.cron.yaml