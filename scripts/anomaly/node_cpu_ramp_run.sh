kubectl apply -f cpu-payload-template.ramp.yaml
kubectl apply -f cpu-payload-env.ramp.configmap.yaml
kubectl apply -f cpu-payload-script.ramp.configmap.yaml
kubectl apply -f cpu-payload.ramp.cron.yaml

# OPT: manual trigger
kubectl -n chaosblade create job --from=cronjob/cpu-singlenode-ramp-payload-jitter cpu-payload-ramp-manual-$(date +%Y%m%d%H%M%S)

# Monitor Job status
JOB=$(kubectl -n chaosblade get jobs --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}')
echo "JOB=$JOB"
kubectl -n chaosblade logs -f job/"$JOB"

# Revert
kubectl delete -f cpu-payload-template.ramp.yaml
kubectl delete -f cpu-payload-env.ramp.configmap.yaml
kubectl delete -f cpu-payload-script.ramp.configmap.yaml
kubectl delete -f cpu-payload.ramp.cron.yaml