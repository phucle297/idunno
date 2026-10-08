# EC2 playtest deployment — Task 2.2.7

One EC2, no EKS/Kubernetes, ECS, ALB, NAT Gateway, Route 53 migration or registry.
Terraform provisions infrastructure; it does **not** ship a game build or run a
deployment pipeline. Only create `dev` for the current playtest. Live apply,
DNS changes, deployment/restart and destroy need approval; none has run yet.

## Boundaries and stages

- **Provision role:** existing stage-specific operator role, supplied as
  `provision_role_arn`. Authenticate with AWS SSO/short-lived credentials; the
  AWS provider assumes this role. Do not commit keys or run from a root account.
  Its reviewed policy must allow the EC2/VPC/EIP resources in this module and
  management of that stage's runtime role/profile; scope `iam:PassRole` to that
  runtime role with `iam:PassedToService = ec2.amazonaws.com`. Do not give the
  game this policy. An authorized account administrator bootstraps this role,
  trust and permissions; this module does not create its own provisioning access.
- **Host runtime role:** module creates `disaster-party-<stage>-runtime`, trusted
  only by EC2, with `AmazonSSMManagedInstanceCore` for host management. No
  game-specific AWS permissions, provisioning or DNS access. Check SSM agent
  health on the selected Ubuntu AMI before relying on Session Manager. The app
  runs as the unprivileged `disaster-party` Linux user, not as root.
- **Future CI/deploy identity:** not implemented here. Use GitHub OIDC and a
  separate stage-specific deploy role, scoped to artifact delivery/that instance;
  never reuse the provisioning role or store long-lived AWS keys. CI should
  validate/build first and require an environment approval before restart.
- **Stage isolation:** `dev`, `staging`, `prod` have distinct resource names,
  domains, provision roles and **S3 state keys**. Prefer separate AWS accounts,
  particularly for prod. Changing `stage` alone does not isolate state: never
  reuse a backend key or use Terraform workspaces as an IAM security boundary.
  Other stages are configuration support, not deployed environments or proof
  of production readiness. Use e.g. `server-staging.permees.com` for staging.

## Local validation (no AWS credentials/calls)

Install Terraform >=1.13, <2 using the official signed release. Commit the
provider lock file. From repository root:

```bash
terraform -chdir=infra/ec2 init -backend=false
terraform -chdir=infra/ec2 fmt -check -recursive
terraform -chdir=infra/ec2 validate
terraform -chdir=infra/ec2 test
```

Tests use a mocked AWS provider; they do not provision instances or verify AWS
permissions, Ubuntu cloud-init installation, DNS, ACME issuance or public UDP.

## Prepare a real plan

Choose the account/budget and check regional EC2/EBS/public IPv4 costs first.
Default: Singapore `ap-southeast-1`, Ubuntu 24.04 x86_64, `t3.small` (2 vCPU,
2 GiB), encrypted 16-GiB gp3 disk, two rooms/four players each. Burstable CPU
uses standard credits to avoid unlimited-credit charges; profile sustained load
and monitor throttling. These are initial test settings, not capacity promises.

Prerequisites outside this module: authenticated operator, provision role,
existing regional SSH key pair and private versioned/encrypted S3 state bucket
with public access blocked. The backend identity needs only its stage's state
object and `.tflock` (Get/Put, Delete lock) plus narrowly scoped bucket List.
Backend authentication is separate from provider `assume_role`; use a profile or
reviewed backend assume-role configuration when the bucket is in another account.
Use a permissions boundary/account policy where required by your organization.

```bash
cp infra/ec2/dev.tfvars.example infra/ec2/dev.tfvars
cp infra/ec2/backend.hcl.example infra/ec2/backend.hcl
# Replace example account/role, operator IPv4 /32, key name and state bucket.
# Ensure stage=dev matches key=disaster-party/dev/terraform.tfstate.
terraform -chdir=infra/ec2 init -reconfigure -backend-config=backend.hcl
terraform -chdir=infra/ec2 plan -var-file=dev.tfvars -out=dev.tfplan
```

Review the account, region, proposed AMI, resources and cost before approving
`terraform -chdir=infra/ec2 apply dev.tfplan`. This command creates paid resources
and public network rules. Pin `ami_id` to the reviewed/tested image in tfvars:
otherwise a newer Canonical AMI can propose instance replacement on a later plan.
Bootstrap changes also replace the instance; review replacements and back up
needed data. Terraform state/plans/local configuration are ignored by Git.
For another stage use its own working copy/backend key, role, tfvars and domain.

The module opens TCP80/443 (ACME/HTTPS), UDP29810–29811 (gameplay) and TCP22
only from the operator /32. Port29800 and Caddy's admin API are not public.
No AAAA record/IPv6 route is configured. In Spaceship create only the A record
shown by `terraform output dns_record`; keep the apex GitHub Pages records intact.
Wait for DNS propagation, then inspect cloud-init and Caddy certificate logs.

## First bundle deployment (operator-approved, not executed)

Copy the tested Linux TAR to the instance using the existing SSH key:

```bash
scp -i /path/to/private-key.pem DisasterParty-Linux-94ad2fd.tar.gz ubuntu@PUBLIC_IP:/tmp/
ssh -i /path/to/private-key.pem ubuntu@PUBLIC_IP
sudo cloud-init status --wait
sudo journalctl -u caddy --no-pager -n 50
```

On EC2, use a fresh revision directory. The following example is pinned to the
already-tested bundle; new releases require a matching Windows client:

```bash
REV=94ad2fd9e095c80802ef14f086c42065969ec7bc
DEST=/opt/disaster-party/releases/$REV
sudo mkdir "$DEST"
sudo tar -xzf /tmp/DisasterParty-Linux-94ad2fd.tar.gz -C "$DEST"
sudo sh -c "cd '$DEST' && sha256sum -c SHA256SUMS.txt"
test "$(sed -n 's/^Source revision: //p' "$DEST/BUILD.txt")" = "$REV"
sudo chmod +x "$DEST/DisasterParty.x86_64"
sudo chown -R root:root "$DEST"
# Stop affects all active rooms. Do not do this during an unannounced live match.
sudo systemctl stop disaster-party
sudo ln -sfn "$DEST" /opt/disaster-party/current
sudo sed -i "s/^BUILD_REVISION=.*/BUILD_REVISION=$REV/" /etc/disaster-party/server.env
sudo systemctl start disaster-party
sudo journalctl -u disaster-party --no-pager -n 50
```

Confirm `ROOM_SERVICE_READY` with the exact revision. Only HTTP Create launches
a game process; startup of the service is not proof of admission/gameplay.
The systemd unit gives the allocator SIGTERM before killing leftover children,
bounds its process group to 2 CPUs/1 GiB, keeps packages read-only and permits
preferences/private room config only in its home/private temp directory.
Inspect logs without tokens/passwords. Rollback stops the service, switches the
symlink and `BUILD_REVISION` to a verified previous bundle and starts it again;
clients must also return to that same revision. Restart invalidates all tickets.

Check from outside EC2:

```bash
curl -i https://server.permees.com/internal/heartbeat  # Must be 404, never proxied.
curl -i https://server.permees.com/v1/rooms/join      # GET must be 404; API is POST.
```

The Caddy proxy accepts only the two exact POST routes, caps bodies at2048 bytes,
and leaves backend startup up to20 seconds. Access/body logs are not enabled.
Backend's30-request/minute backstop is shared by proxy callers; there is no
per-client edge rate limiter/WAF yet. This is a small controlled playtest, not
public abuse-resilient hosting. Separate-network Windows release checks,
physical audio/settings confirmation and deployment-hardware profiling remain
required before closing2.2.7. See the full acceptance in `GUIDE.md`.

Stop EC2 does not remove disk/EIP costs. Destroy requires explicit approval and
removes this stage's instance/disk/network; remove its DNS A record separately.
Keep state-bucket history and downloaded validation artifacts under the agreed
retention policy. No automated apply, DNS change or game restart is wired here.
