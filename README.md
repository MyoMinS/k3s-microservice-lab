# Single-node k3s, Gateway API, Argo CD and two Node.js services on AWS

This **demo** deploys one Ubuntu 24.04 EC2 instance running a single-node k3s cluster, ECR repositories, cert-manager, Traefik and Argo CD. Traefik's Kubernetes Gateway API provider exposes `GET /dog`, `GET /cat` and the requested `/cate` alias; all return `ok`. Argo CD watches the Git manifests, not CI's access to the cluster.

## Prerequisites

- AWS credentials authorized to manage EC2, networking, IAM, ECR and SSM; an existing EC2 SSH key pair in the selected region; a public GitHub repository.
- Locally installed Terraform >= 1.6, `kubectl`, Git and SSH/SCP. GitHub-hosted runners supply Docker, Node.js and Python.
- Use **a remote Terraform state backend with locking** if collaborating. Local Terraform state, a copied kubeconfig and your SSH private key are secrets: never commit them. `.gitignore` excludes state, `*.tfvars`, `*.pem`, and kubeconfigs.
- Costs: EC2, a public IPv4/Elastic IP, EBS, ECR and data transfer are chargeable. This is a public, single-node, **HTTP-only** demonstration; cert-manager is installed but no issuer, domain, or TLS certificate is configured. For production add DNS, HTTPS Gateway listener/cert-manager issuer, backups, HA, and restricted inbound HTTP CIDRs.

## 1. Provision AWS and k3s

Use an AWS CLI profile or environment variables for your AWS account. Edit the copied variables file and replace the example SSH key pair, your **real public IP/32**, region, and `github_repository` with `owner/repo`. The default project name (`k3s-microservice-lab`) determines both ECR repository names and must match the CI variable.

```sh
cp infra/aws/terraform.tfvars.example infra/aws/terraform.tfvars
terraform -chdir=infra/aws init
terraform -chdir=infra/aws apply
terraform -chdir=infra/aws output
```

AWS uses Canonical's public SSM parameter for the latest Ubuntu 24.04 amd64 AMI in the region. EC2 user data installs k3s `v1.34.3+k3s1`, disables bundled Traefik, and builds the matching ECR kubelet credential provider. The instance profile supplies ECR **pull** rights. It takes several minutes; Terraform completing only means the VM was created. The gateway is exposed on the EC2 Elastic IP using k3s ServiceLB (no AWS Load Balancer). SSH and API port 6443 accept traffic only from `admin_cidr`.

Inspect provisioning and copy kubeconfig locally after bootstrap finishes:

```sh
IP=$(terraform -chdir=infra/aws output -raw public_ip)
ssh -i /path/to/key.pem ubuntu@"$IP" 'sudo cloud-init status --wait && sudo systemctl is-active k3s && sudo kubectl get nodes'
ssh -i /path/to/key.pem ubuntu@"$IP" 'sudo cat /etc/rancher/k3s/k3s.yaml' > kubeconfig-local
# The certificate contains the Elastic IP from bootstrapping:
sed -i.bak "s/127.0.0.1/$IP/g" kubeconfig-local
chmod 600 kubeconfig-local
KUBECONFIG="$PWD/kubeconfig-local" kubectl get nodes
```

On Windows, replace the `sed` step with a text-editor replacement of `127.0.0.1` with the Elastic IP; pass the absolute path to the next Terraform stage. If provisioning fails, inspect `sudo tail -n 100 /var/log/k3s-bootstrap.log` and `sudo journalctl -u k3s -n 100` via SSH. The installer temporarily creates a 2-GB swapfile for building the Go ECR plugin and removes it before k3s starts.

## 2. Install cluster add-ons via Terraform

Copy `infra/addons/terraform.tfvars.example` to `infra/addons/terraform.tfvars` and specify the **absolute path** to the local kubeconfig. On Windows Terraform local-exec needs `kubectl.exe` in `PATH`. This stage first installs Gateway API v1.3.0 standard CRDs, then the Helm charts; Traefik's chart creates `GatewayClass/traefik` and `Gateway/traefik-gateway` with a cross-namespace HTTP listener. Argo CD UI is not publicly exposed.

```sh
terraform -chdir=infra/addons init
terraform -chdir=infra/addons apply
KUBECONFIG="$PWD/kubeconfig-local" kubectl get gateway -n traefik
KUBECONFIG="$PWD/kubeconfig-local" kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Argo CD's UI is then at `https://localhost:8080` (self-signed TLS); its bootstrap admin password is obtained with `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`. Rotate it promptly. The add-ons Terraform stage needs a working cluster; it cannot be applied at the same time as AWS provisioning. CRDs are deliberately not deleted on `terraform destroy` to avoid deleting custom resources.

## 3. Configure CI and GitOps

1. Push this repository to the **public GitHub repo** specified as `github_repository` in the AWS Terraform stage, on the `main` branch. If changing the repo after provisioning, re-apply `infra/aws` to update the OIDC trust policy.
2. In `argocd/application.yaml`, replace `https://github.com/YOUR_ORG/k3s-microservice-lab.git` with your real public HTTPS Git URL, then commit and push it. For private repos, configure Argo CD repository authentication separately; no Git credentials are included here.
3. Set GitHub Actions repository **variables** `AWS_REGION` and `PROJECT_NAME` to the Terraform values (e.g. `us-east-1` and `k3s-microservice-lab`). Set repository **secret** `AWS_GITHUB_ACTIONS_ROLE_ARN` to `terraform -chdir=infra/aws output -raw github_actions_role_arn`. Terraform creates a least-privilege ECR push role restricted by GitHub OIDC to `main` of this repository; no permanent AWS access keys required.
4. Allow Actions to write repository contents under Settings → Actions → General → Workflow permissions, and ensure `main` branch rules allow GitHub Actions commits. Otherwise use a PR-based manifest update instead. Trigger `Build and deploy via GitOps` using `workflow_dispatch` (or push a change under `apps/`). It tests both services, builds and pushes both images tagged with the commit SHA, and **commits their full ECR references to `k8s/apps/{dog,cat}.yaml`**. Its manifest-only commit does not retrigger the workflow.
5. After the first successful workflow, apply the Argo CD Application (or use `kubectl` on the EC2 host):

```sh
KUBECONFIG="$PWD/kubeconfig-local" kubectl apply -f argocd/application.yaml
KUBECONFIG="$PWD/kubeconfig-local" kubectl -n argocd get application animals
KUBECONFIG="$PWD/kubeconfig-local" kubectl -n demo get pods,svc,httproute
curl "http://$IP/dog"   # ok
curl "http://$IP/cat"   # ok
curl "http://$IP/cate"  # ok
```

Until CI writes real image references, the manifest images use **nonexistent bootstrap ECR URLs** and pods cannot pull. Wait for the first build before creating the Argo CD Application. The instance's ECR plugin uses the EC2 instance role for image pulls (no manually rotated `imagePullSecrets`). The HTTPRoute references the chart-created Gateway in namespace `traefik`; Traefik permits routes from `demo` with `namespacePolicy.from: All`.

## Local verification and cleanup

```sh
(cd apps/dog && npm test)
(cd apps/cat && npm test)
python3 -m unittest discover -s scripts -p 'test_*.py'
kubectl kustomize k8s/apps
terraform -chdir=infra/aws fmt -check -recursive
terraform -chdir=infra/addons fmt -check -recursive
```

Delete the Argo CD Application first, then `terraform -chdir=infra/addons destroy`, then `terraform -chdir=infra/aws destroy`. This terminates the EC2 instance and deletes the two ECR repositories **only if empty**; delete their images before destroying to avoid Terraform deletion errors. Gateway API CRDs may remain on the cluster until it is terminated.


```sh
kubectl create secret generic awssm-secret --from-file=./access-key  --from-file=./secret-access-key
```