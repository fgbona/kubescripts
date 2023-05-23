#!/bin/bash
# Dependencies: apt install jq

# Check if a worker node name is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <worker-node-name>"
  exit 1
fi

WORKER_NODE=$1
BACKUP_DIR="/path/to/backup/dir" # Replace with the path to your backup directory
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Get all Pods running on the worker node
kubectl get pods --all-namespaces -o json --field-selector spec.nodeName=${WORKER_NODE} > all_pods.json

# Backup StatefulSets
STATEFULSET_PODS=$(jq -r '.items[] | select(.metadata.ownerReferences[]? | .kind=="StatefulSet") | .metadata.namespace + "/" + .metadata.ownerReferences[].name' all_pods.json | sort -u)

IFS=$'\n'
for POD in $STATEFULSET_PODS; do
  NAMESPACE=$(echo $POD | cut -d/ -f1)
  STATEFULSET=$(echo $POD | cut -d/ -f2)
  BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_${NAMESPACE}_${STATEFULSET}.yaml"
  kubectl get statefulset -n $NAMESPACE $STATEFULSET -o yaml > $BACKUP_FILE
  echo "Backup of statefulset '${NAMESPACE}/${STATEFULSET}' saved to '${BACKUP_FILE}'"
done

# Backup PVCs
PVCs=$(jq -r '.items[] | .metadata.namespace + "/" + (.spec.volumes[]? | select(has("persistentVolumeClaim")) | .persistentVolumeClaim.claimName)' all_pods.json | sort -u)

IFS=$'\n'
for PVC_INFO in $PVCs; do
  NAMESPACE=$(echo "${PVC_INFO}" | cut -d/ -f1)
  PVC_NAME=$(echo "${PVC_INFO}" | cut -d/ -f2)

  # Create a backup of the PVC resource
  PVC_BACKUP_FILE="${BACKUP_DIR}/${TIMESTAMP}_${NAMESPACE}_${PVC_NAME}_pvc.yaml"
  kubectl get pvc -n "${NAMESPACE}" "${PVC_NAME}" -o yaml > "${PVC_BACKUP_FILE}"
  echo "Backup of PVC '${NAMESPACE}/${PVC_NAME}' saved to '${PVC_BACKUP_FILE}'"
done

# Remove the temporary all_pods.json file
rm all_pods.json
