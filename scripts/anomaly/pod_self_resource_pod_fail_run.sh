#!/usr/bin/env bash
kubectl apply -f pod-payload-template.pod.fail.yaml
kubectl apply -f pod-payload-env.pod.fail.configmap.yaml
kubectl apply -f pod-payload-script.pod.fail.configmap.yaml
kubectl apply -f pod-payload.pod.fail.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/pod-payload-pod-fail mem-payload-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Roll back
kubectl delete -f pod-payload-template.pod.fail.yaml
kubectl delete -f pod-payload-env.pod.fail.configmap.yaml
kubectl delete -f pod-payload-script.pod.fail.configmap.yaml
kubectl delete -f pod-payload.pod.fail.cron.yaml