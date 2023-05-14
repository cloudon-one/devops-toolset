#!/bin/bash
set -ex

GCP_PROJECT=${1:-$GCP_PROJECT}
GCP_REGION=${2:-$GCP_REGION}
GKE_CLUSTER_NAME=${3:-$GKE_CLUSTER} ## take from GCP Console/gcloud/state
GITLAB_RUNNER_REGISTRATION_TOKEN=${4:-$GITLAB_TOKEN} ## take form gitlab-->Settings-->CICD-->Advanced--_Runners
GITLAB_RUNNER_LOG_LEVEL="${GITLAB_RUNNER_LOG_LEVEL:-debug}"

gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" --region "$GCP_REGION" --project "$GCP_PROJECT"

kubectl get ns gitlab-ci || kubectl create ns gitlab-ci
kubectl --namespace gitlab-ci get sa gitlab-runner || kubectl --namespace gitlab-ci create sa gitlab-runner

#Create IAM service account
gcloud iam service-accounts describe "gitlab-runner@$GCP_PROJECT.iam.gserviceaccount.com"  --project "$GCP_PROJECT" || gcloud iam service-accounts create gitlab-runner --project "$GCP_PROJECT"

#Binding a role of workloadIdentityUser for GSA IAM
 gcloud iam service-accounts add-iam-policy-binding \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${GCP_PROJECT}.svc.id.goog[gitlab-ci/gitlab-runner]" \
  gitlab-runner@${GCP_PROJECT}.iam.gserviceaccount.com --project "$GCP_PROJECT"

#Binding a role of GKE developer for GSA IAM
gcloud projects add-iam-policy-binding "$GCP_PROJECT" --role roles/storage.objectAdmin --member "serviceAccount:gitlab-runner@$GCP_PROJECT.iam.gserviceaccount.com"
gcloud projects add-iam-policy-binding "$GCP_PROJECT" --role roles/container.developer --member "serviceAccount:gitlab-runner@$GCP_PROJECT.iam.gserviceaccount.com"

#Binding KSA and GSA
kubectl annotate serviceaccount --namespace gitlab-ci  gitlab-runner \
  iam.gke.io/gcp-service-account=gitlab-runner@${GCP_PROJECT}.iam.gserviceaccount.com \
  --overwrite

kubectl --namespace gitlab-ci apply -f pvc.yaml
kubectl apply -f clusterrolebinding.yaml

helm upgrade gitlab-runner gitlab/gitlab-runner --install --namespace gitlab-ci -f ./values.yaml \
  --set gitlabUrl=https://gitlab.cloudon.one/ \
  --set runnerRegistrationToken="$GITLAB_RUNNER_REGISTRATION_TOKEN" \
  --set name="gitlab-runner-${GKE_CLUSTER_NAME}" \
  --set fullnameOverride="gitlab-runner-${GKE_CLUSTER_NAME}" \
  --set nameOverride="gitlab-runner-${GKE_CLUSTER_NAME}" \
  --set runners.executor=kubernetes \
  --set serviceAccountName=gitlab-runner \
  --set rbac.serviceAccountName=gitlab-runner \
  --set rbac.clusterWideAccess=true \
  --set privileged=true \
  --set runUntagged=true \
  --set logLevel=$GITLAB_RUNNER_LOG_LEVEL \
  --set replicas=1 \
  --set concurrent=10
