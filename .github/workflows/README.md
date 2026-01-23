# GitHub Actions Workflows

## Deploy to EC2

This workflow automatically deploys the latest code to your EC2 instance when you push to the `master` branch. It uses **AWS OIDC authentication** and **AWS Secrets Manager** for secure access.

### Required Secrets

#### AWS Secrets Manager (Managed by Infrastructure Repo)

These secrets are automatically created/updated by your infrastructure repository:

| Secret Name | Description |
|-------------|-------------|
| `k8s-vms/ec2-ssh-private-key` | EC2 SSH private key (PEM format) |
| `k8s-vms/ec2-host-ip` | EC2 instance public IP address |

#### GitHub Repository Secrets (One-Time Setup)

| Secret Name | Description | Example Value |
|-------------|-------------|---------------|
| `AWS_OIDC_ROLE_ARN` | AWS IAM Role ARN for OIDC | `arn:aws:iam::123456789012:role/github-actions-role` |
| `EC2_USER` | SSH username | `ubuntu` |
| `DEPLOY_PATH` | Deployment path on EC2 | `/home/ubuntu/on-prem-k8s` |

### Architecture

```
Infrastructure Repo
  ↓
Creates EC2 + Stores secrets in AWS Secrets Manager
  ├─ k8s-vms/ec2-ssh-private-key
  └─ k8s-vms/ec2-host-ip
  ↓
GitHub Actions (this repo)
  ↓
Uses OIDC to authenticate to AWS
  ↓
Retrieves secrets from AWS Secrets Manager
  ↓
Deploys code to EC2
```

### Setup Instructions

#### 1. AWS OIDC Role Setup (Infrastructure Repo)

Your infrastructure repository should create an IAM role with OIDC trust policy:

**Trust Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_USERNAME/on-prem-k8s:*"
        }
      }
    }
  ]
}
```

**IAM Policy (attach to role):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT_ID:secret:k8s-vms/ec2-ssh-private-key-*",
        "arn:aws:secretsmanager:us-east-1:YOUR_ACCOUNT_ID:secret:k8s-vms/ec2-host-ip-*"
      ]
    }
  ]
}
```

**Terraform Example (for infrastructure repo):**
```hcl
# OIDC Provider
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role
resource "aws_iam_role" "github_actions_deploy" {
  name = "github-actions-on-prem-k8s-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:YOUR_USERNAME/on-prem-k8s:*"
          }
        }
      }
    ]
  })
}

# IAM Policy
resource "aws_iam_role_policy" "github_actions_secrets_access" {
  name = "secrets-manager-access"
  role = aws_iam_role.github_actions_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:k8s-vms/*"
        ]
      }
    ]
  })
}

# Store SSH key in Secrets Manager
resource "aws_secretsmanager_secret" "ec2_ssh_key" {
  name = "k8s-vms/ec2-ssh-private-key"
}

resource "aws_secretsmanager_secret_version" "ec2_ssh_key" {
  secret_id     = aws_secretsmanager_secret.ec2_ssh_key.id
  secret_string = tls_private_key.ec2_ssh.private_key_pem
}

# Store EC2 IP in Secrets Manager
resource "aws_secretsmanager_secret" "ec2_ip" {
  name = "k8s-vms/ec2-host-ip"
}

resource "aws_secretsmanager_secret_version" "ec2_ip" {
  secret_id     = aws_secretsmanager_secret.ec2_ip.id
  secret_string = aws_instance.k8s_host.public_ip
}
```

#### 2. Configure GitHub Secrets

Set these secrets in this repository (one-time setup):

**Via GitHub CLI:**
```bash
gh secret set AWS_OIDC_ROLE_ARN -b "arn:aws:iam::123456789012:role/github-actions-on-prem-k8s-deploy"
gh secret set EC2_USER -b "ubuntu"
gh secret set DEPLOY_PATH -b "/home/ubuntu/on-prem-k8s"
```

**Or via GitHub UI:**
- Repository → Settings → Secrets and variables → Actions → New repository secret

#### 3. Test the Workflow

```bash
# Make a change
echo "# Test AWS OIDC deployment" >> README.md
git add README.md
git commit -m "Test AWS OIDC deployment workflow"
git push origin master

# Check workflow status
# GitHub → Actions tab
```

### What the Workflow Does

1. **Triggers** on push to `master` branch
2. **Authenticates** to AWS using OIDC (no long-lived credentials!)
3. **Retrieves** SSH key from AWS Secrets Manager
4. **Retrieves** EC2 IP from AWS Secrets Manager
5. **Connects** to EC2 via SSH
6. **Deploys** latest code (clone or pull)
7. **Cleans up** SSH keys from runner

### Benefits of AWS Secrets Manager + OIDC

✅ **No long-lived credentials** - OIDC tokens are short-lived
✅ **Centralized secret management** - All infrastructure secrets in one place
✅ **Automatic rotation** - Infrastructure repo updates secrets when recreating EC2
✅ **Audit trail** - AWS CloudTrail logs all secret access
✅ **Fine-grained permissions** - IAM policies control access

### Workflow Status Badge

Add this to your README.md:

```markdown
[![Deploy to EC2](https://github.com/YOUR_USERNAME/on-prem-k8s/actions/workflows/deploy.yml/badge.svg)](https://github.com/YOUR_USERNAME/on-prem-k8s/actions/workflows/deploy.yml)
```

### Troubleshooting

**"Unable to assume role":**
- Verify OIDC provider is set up in AWS
- Check trust policy matches your repository name exactly
- Ensure `AWS_OIDC_ROLE_ARN` secret is correct

**"Access Denied" when getting secrets:**
- Verify IAM role has policy to read secrets
- Check secret names match exactly: `k8s-vms/ec2-ssh-private-key` and `k8s-vms/ec2-host-ip`
- Verify secrets exist in AWS Secrets Manager

**"SSH key secret not found":**
- Check infrastructure repo has created the secret
- Verify secret name is `k8s-vms/ec2-ssh-private-key`
- Ensure secret is in correct AWS region (`us-east-1`)

**"Connection refused":**
- Check EC2 security group allows SSH (port 22) from GitHub Actions IPs
- GitHub Actions IP ranges: https://api.github.com/meta (check `actions` field)
- Or allow SSH from anywhere (0.0.0.0/0) for testing

**"Permission denied (publickey)":**
- Verify SSH key in AWS Secrets Manager is the correct one for EC2 instance
- Check key format includes proper header/footer

### Security Best Practices

- ✅ Use OIDC instead of long-lived AWS access keys
- ✅ Apply principle of least privilege to IAM role
- ✅ Use specific resource ARNs in IAM policies (not `*`)
- ✅ Enable AWS CloudTrail for audit logging
- ✅ Rotate EC2 SSH keys periodically
- ✅ Keep secrets in AWS Secrets Manager, not GitHub Secrets
- ✅ Use EC2 security groups to restrict SSH access

### Complete Workflow

Your end-to-end setup:

```
1. Infrastructure Repo: terraform apply
   ↓
2. EC2 instance created
   ↓
3. SSH key + IP stored in AWS Secrets Manager
   ↓
4. OIDC role grants this repo access to secrets
   ↓
5. Push code to master in this repo
   ↓
6. GitHub Actions uses OIDC to get secrets
   ↓
7. Code deployed to EC2
```

When you recreate the instance, just run terraform apply again - secrets are automatically updated!
