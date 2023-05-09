# Deploy ExternalDNS on GKE cluster with Workload Identity

### Create a GCP service account (GSA) for ExternalDNS and save its email address

       SA_NAME="Kubernetes external-dns" 
       gcloud iam service-accounts create sa-edns --display-name="$SA_NAME" 
       SA_EMAIL=$(gcloud iam service-accounts list --format='value(email)' --filter="displayName:$sa_name")

### Bind the ExternalDNS GSA to the DNS admin role

    PROJECT_ID = "your-gcp-project-id"
    gcloud projects add-iam-policy-binding $PROJECT_ID
    --member="serviceAccount:$SA_EMAIL" --role=roles/dns.admin ''

### Link the ExternalDNS GSA to the Kubernetes service account (KSA) that external-dns will run under

    gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --member="serviceAccount:$PROJECT_ID.svc.id.goog[external-dns/external-dns]" \
    --role=roles/iam.workloadIdentityUser

### Deploy ExternalDNS

    kubectl apply -f values.yaml -n "YOUR_NAMESPACE"
    helm install external-dns \
    --set provider=google \
    --set google.serviceAccountSecret=external-dns \
    --set policy=upsert-only \
    --set registry=txt \
    --set txtOwnerId=ext-dns \
    --set rbac.create=false \
    --set domainFilters={your.domain.com.} \
    --set sources="{ingress,istio-gateway,service}" -n external-dns \
   bitnami/external-dns
