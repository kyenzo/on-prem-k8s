# Infrastructure Repository Setup Instructions

This document describes what needs to be configured in your infrastructure repository to enable the deployment workflow in this repository.

## Required Changes to Infrastructure Repo

### 1. Add Repository to Allowed Repositories

In your infrastructure repo's Terraform configuration where you call the GitHub OIDC module, add this repository to the `allowed_repositories` variable:

```hcl
module "github_oidc" {
  source = "./modules/github-oidc"  # or wherever your module is

  role_name = "github-actions-role"

  # Add the on-prem-k8s repo here
  allowed_repositories = [
    "YOUR_GITHUB_USERNAME/infrastructure-repo",  # Your existing infrastructure repo
    "YOUR_GITHUB_USERNAME/on-prem-k8s"           # ADD THIS LINE
  ]

  # Secrets that the role can access
  allowed_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:k8s-vms/*"
  ]

  tags = var.tags
}
```

### 2. Ensure Secrets Are Created

Your infrastructure repo should create these secrets in AWS Secrets Manager:

```hcl
# SSH Private Key Secret
resource "aws_secretsmanager_secret" "ec2_ssh_key" {
  name = "k8s-vms/ec2-ssh-private-key"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "ec2_ssh_key" {
  secret_id     = aws_secretsmanager_secret.ec2_ssh_key.id
  secret_string = tls_private_key.ec2_ssh.private_key_pem
}

# EC2 Host IP Secret
resource "aws_secretsmanager_secret" "ec2_ip" {
  name = "k8s-vms/ec2-host-ip"

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "ec2_ip" {
  secret_id     = aws_secretsmanager_secret.ec2_ip.id
  secret_string = aws_instance.k8s_host.public_ip
}
```

## Required GitHub Secrets (This Repo)

Set these secrets in **this repository** (on-prem-k8s):

```bash
# Your AWS Account ID (12-digit number)
gh secret set AWS_ACCOUNT_ID -b "123456789012"
```

Or via GitHub UI:
- Go to: Repository → Settings → Secrets and variables → Actions
- Click: New repository secret
- Name: `AWS_ACCOUNT_ID`
- Value: Your 12-digit AWS account ID

## How It Works

```
1. Infrastructure Repo: terraform apply
   ↓
2. Creates/Updates:
   - EC2 instance
   - AWS Secrets Manager secrets:
     * k8s-vms/ec2-ssh-private-key
     * k8s-vms/ec2-host-ip
   - IAM OIDC role with trust policy allowing this repo
   ↓
3. This Repo: git push to master
   ↓
4. GitHub Actions workflow:
   - Authenticates via OIDC (no credentials stored!)
   - Retrieves secrets from AWS Secrets Manager
   - SSHs to EC2 and deploys code
```

## Verification

After updating your infrastructure repo and running `terraform apply`, verify:

### 1. Check OIDC Role Trust Policy

```bash
aws iam get-role --role-name github-actions-role --query 'Role.AssumeRolePolicyDocument'
```

Should show:
```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:YOUR_USERNAME/infrastructure-repo:*",
      "repo:YOUR_USERNAME/on-prem-k8s:*"
    ]
  }
}
```

### 2. Check Secrets Exist

```bash
aws secretsmanager list-secrets --query 'SecretList[?starts_with(Name, `k8s-vms/`)].Name'
```

Should show:
```json
[
  "k8s-vms/ec2-ssh-private-key",
  "k8s-vms/ec2-host-ip"
]
```

### 3. Test Secret Access

```bash
aws secretsmanager get-secret-value --secret-id "k8s-vms/ec2-host-ip" --query 'SecretString' --output text
```

Should return the EC2 IP address.

## Troubleshooting

**"Unable to assume role" error in workflow:**
- Verify `on-prem-k8s` is in `allowed_repositories` in your infrastructure Terraform
- Run `terraform apply` to update the IAM role trust policy
- Check that `AWS_ACCOUNT_ID` secret is set correctly in this repo

**"Secret not found" error:**
- Verify secrets exist: `aws secretsmanager list-secrets`
- Check secret names match exactly: `k8s-vms/ec2-ssh-private-key` and `k8s-vms/ec2-host-ip`
- Ensure infrastructure Terraform has created the secrets

**"Access Denied" when getting secrets:**
- Verify the IAM role has the secrets policy attached
- Check `allowed_secret_arns` includes `k8s-vms/*`

## Complete Terraform Example

Here's a minimal example of what your infrastructure repo should have:

```hcl
# Data source for current AWS account
data "aws_caller_identity" "current" {}

# GitHub OIDC module
module "github_oidc" {
  source = "./modules/github-oidc"

  role_name = "github-actions-role"

  allowed_repositories = [
    "YOUR_USERNAME/infrastructure-repo",
    "YOUR_USERNAME/on-prem-k8s"  # This repo!
  ]

  allowed_secret_arns = [
    "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:k8s-vms/*"
  ]

  create_oidc_provider = true  # Set to false if already exists

  tags = {
    Project = "on-prem-k8s"
    ManagedBy = "terraform"
  }
}

# Output the role ARN for verification
output "github_actions_role_arn" {
  value = module.github_oidc.role_arn
}
```

## Next Steps

1. Update infrastructure repo with the changes above
2. Run `terraform apply` in infrastructure repo
3. Set `AWS_ACCOUNT_ID` secret in this repo
4. Push to master in this repo to trigger deployment
5. Check GitHub Actions tab for workflow execution
