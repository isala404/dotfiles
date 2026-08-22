---
name: email-setup
description: Use when mail isn't sending or the AWS SES/SMTP setup needs checking or changing, including SES identities, regions, DKIM, MAIL FROM, sandbox limits, quotas, SMTP IAM users, or SMTP secrets in Kubernetes.
---

# Email setup

**Requires:** `aws` CLI with a working profile, and `kubectl` with cluster context for the deployment checks. Credentials come from the Bitwarden helper. See the `bws-secrets` skill, and use it for anything involving a secret value. If a profile or cluster context is unavailable, say which check you couldn't run and fall back to the GitOps repo; don't guess at live state.

Use live AWS and repository state as the source of truth. Do not assume profile names, account ownership, regions, identities, quotas, SMTP users, or deployed workloads from an old report.

## Scope

Discovery and diagnosis are the default, and they are read-only. Sending is an external side effect, so never use a test send as a health check.

Anything that changes state, including creating an IAM user, writing a secret, editing an ExternalSecret, rolling a deployment, or revoking a key, happens only when the user explicitly asked for that change. Diagnosing a delivery failure does not authorize fixing it; report the cause and what the fix would be, then wait. Keep rotation work separate from a read-only investigation rather than folding it in.

## Discover the AWS CLI setup

List every configured profile, its configured region, and its authenticated AWS identity:

```bash
aws --version
aws configure list-profiles
aws configure get region --profile <profile>
aws configure get credential_process --profile <profile>
aws sts get-caller-identity --profile <profile> --output json
```

Use the profile's configured region when present. When it is empty, enumerate regions instead of guessing. If the credential helper reports a macOS keychain or decryption-key error, retry the read-only AWS command with approved host access; do not copy credentials into the workspace.

For each authenticated profile, record the account, IAM principal, configured region, and whether SES inspection is authorized. Use the account and principal only for the current task; discover them again on the next task.

## Find the active SES account and region

SES is regional. For each usable profile, enumerate available regions and inspect SES v2 account and identity metadata:

```bash
aws ec2 describe-regions \
  --profile <profile> --all-regions \
  --query 'Regions[].RegionName' --output text

aws sesv2 get-account \
  --profile <profile> --region <region> \
  --query '{ProductionAccessEnabled:ProductionAccessEnabled,SendingEnabled:SendingEnabled,EnforcementStatus:EnforcementStatus,SendQuota:SendQuota}' \
  --output json

aws sesv2 list-email-identities \
  --profile <profile> --region <region> \
  --query 'EmailIdentities[].{Identity:IdentityName,Type:IdentityType,Status:VerificationStatus,SendingEnabled:SendingEnabled}' \
  --output json
```

The operational sending region normally has `ProductionAccessEnabled: true`, `SendingEnabled: true`, a healthy enforcement status, and one or more verified identities. Confirm rather than assuming; an account can have SES enabled in multiple regions.

For each identity that matters, inspect DKIM and MAIL FROM:

```bash
aws sesv2 get-email-identity \
  --profile <profile> --region <region> \
  --email-identity <identity> \
  --query '{IdentityType:IdentityType,VerifiedForSendingStatus:VerifiedForSendingStatus,DkimStatus:DkimAttributes.Status,SigningOrigin:DkimAttributes.SigningAttributesOrigin,MailFromDomain:MailFromAttributes.MailFromDomain,MailFromStatus:MailFromAttributes.MailFromDomainStatus}' \
  --output json
```

Also check legacy SES resources when relevant:

```bash
aws sesv2 list-configuration-sets --profile <profile> --region <region>
aws ses list-templates --profile <profile> --region <region>
aws ses list-receipt-rule-sets --profile <profile> --region <region>
aws ses get-send-quota --profile <profile> --region <region>
```

Do not use a send call as a health check. Sending email is an external side effect.

## Discover SMTP users and permissions

Find IAM users associated with SES or SMTP, then inspect their policies and key metadata:

```bash
aws iam list-users --profile <profile> --output json
aws iam list-attached-user-policies --profile <profile> --user-name <user>
aws iam list-user-policies --profile <profile> --user-name <user>
aws iam list-access-keys --profile <profile> --user-name <user> \
  --query 'AccessKeyMetadata[].{Status:Status,CreateDate:CreateDate,LastUsed:LastUsedDate}'
aws iam get-user-policy --profile <profile> --user-name <user> \
  --policy-name <policy> --output json
```

Prefer a dedicated SMTP user with an inline policy allowing `ses:SendRawEmail` only for the required SES identity resources. Do not use a general administrator or developer credential in an application when a scoped SMTP user exists.

SMTP credentials are region-specific. The SMTP endpoint has the form:

```text
email-smtp.<region>.amazonaws.com:587
```

## Discover application wiring

Search the infrastructure and application repositories for SMTP configuration and secret references:

```bash
rg -n -i '(SMTP_HOST|SMTP_PORT|SMTP_FROM|EMAIL_FROM|SMTP_USER|SMTP_PASS|ExternalSecret|remoteRef)' \
  /path/to/infrastructure /path/to/application
```

For each workload, establish:

1. SMTP host region matches the SES identity region.
2. `SMTP_FROM` or `EMAIL_FROM` is covered by a verified SES identity.
3. SMTP credentials are loaded from a secret manager or ExternalSecret, not a ConfigMap.
4. `remoteRef` points to the intended Bitwarden items.
5. The deployment actually runs the email worker or code path that sends mail.

For the Kubernetes cluster:

```bash
kubectl config current-context
kubectl -n <namespace> get externalsecret <name> -o jsonpath='{.status.conditions[*]}'
kubectl -n <namespace> get pods -l app=<app> -o wide
kubectl -n <namespace> logs deploy/<deployment> --all-containers --since=30m
```

Never dump Kubernetes Secret objects or environment variables into logs. If the cluster context is unavailable, inspect the GitOps repository and report that live workload state could not be verified. Make cluster changes through the repository's GitOps flow rather than applying manifests directly.

## Credential and secret handling

Storing and reading secrets is the `bws-secrets` skill's job. Read it before touching a secret value, and use its commands rather than a variant invented here. The one rule worth repeating: a secret value must never be printed, echoed, logged, or written to an intermediate file. Stream it from `secretctl` into the consumer.

What's specific to email: the SMTP username and password are two separate values, both region-bound, and they reach the cluster through an ExternalSecret rather than being read directly. Capture only the returned secret **ID** because that is what goes in the manifest.

After creating or selecting a secret, put its ID in the private GitOps change as the ExternalSecret `remoteRef.key`:

```yaml
data:
  - secretKey: SMTP_USER
    remoteRef:
      key: "<bws-secret-id>"
  - secretKey: SMTP_PASS
    remoteRef:
      key: "<bws-secret-id>"
```

Use separate BWS secrets when the ExternalSecret expects separate keys. If one BWS item contains a structured value, use the ExternalSecret template or provider-specific property selection supported by the cluster configuration. Never put the secret value in YAML, a ConfigMap, a Git commit, or a task note.

After changing the reference, check ExternalSecret synchronization and roll out the workload. Do not inspect the resulting Kubernetes Secret contents.

For an explicitly requested rotation:

1. Identify the current SMTP user, policy, secret references, and workloads.
2. Create a replacement least-privilege SMTP principal.
3. Store its credentials in Bitwarden through the established workflow.
4. Update the ExternalSecret reference.
5. Wait for synchronization and roll out the workload.
6. Verify the worker and delivery path without dumping secrets.
7. Revoke the old key only after successful validation.

## Troubleshoot by symptom

- **Credential helper failure:** use approved host access for the keychain-backed helper.
- **`AccessDenied` from SES:** check the profile, region, MFA requirement, and IAM policy.
- **Identity not found:** check the SES region; identities do not transfer between regions.
- **Sandbox rejection:** inspect `ProductionAccessEnabled` and verified-recipient restrictions.
- **`MessageRejected`:** compare the sender address with the verified identity and SMTP user's allowed resources.
- **SMTP authentication failure:** verify the credential belongs to the correct region and SMTP user, then check ExternalSecret synchronization.
- **No email from an application:** inspect the non-secret SMTP variables, worker process, pod status, and recent logs.
- **No Kubernetes context:** use the GitOps source and state that runtime verification is unavailable.
