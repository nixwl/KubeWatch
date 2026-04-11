#!/usr/bin/env bash
kubectl apply -f disk-io-payload-template.pod.delay.intermit.yaml
kubectl apply -f disk-io-payload-env.pod.delay.intermit.configmap.yaml
kubectl apply -f disk-io-payload-script.pod.delay.intermit.configmap.yaml
kubectl apply -f disk-io-payload.pod.delay.intermit.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/disk-io-payload-pod-delay-intermit disk-io-payload-manual-$(date +%Y%m%d%H%M%S)

# Wait for the Job/Pod to exist
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | tail -n 1)
echo "JOB=$JOB"
POD=$(kubectl -n chaosblade get pods -l job-name="$JOB" -o jsonpath='{.items[0].metadata.name}')
echo "POD=$POD"
kubectl -n chaosblade logs -f "$POD"

# Roll back
kubectl delete -f disk-io-payload-template.pod.delay.intermit.yaml
kubectl delete -f disk-io-payload-env.pod.delay.intermit.configmap.yaml
kubectl delete -f disk-io-payload-script.pod.delay.intermit.configmap.yaml
kubectl delete -f disk-io-payload.pod.delay.intermit.cron.yaml