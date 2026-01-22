# GitHub Actions Workflows

## Deploy to EC2

This workflow automatically deploys the latest code to your EC2 instance when you push to the `master` branch.

### Required GitHub Secrets

These secrets are **automatically updated** by your infrastructure repository when the EC2 instance is created/recreated.

**Settings → Secrets and variables → Actions**

| Secret Name | Description | Updated By |
|-------------|-------------|------------|
| `EC2_SSH_PRIVATE_KEY` | Private SSH key (PEM) for EC2 access | Infrastructure repo |
| `EC2_HOST` | EC2 instance public IP address | Infrastructure repo |
| `EC2_USER` | SSH username | Infrastructure repo (or set manually once) |
| `DEPLOY_PATH` | Absolute path where code should be deployed | Set manually once |

### Workflow Integration

This repository works in tandem with your infrastructure repository:

```
Infrastructure Repo (creates EC2)
  ↓
Terraform/CloudFormation creates EC2 instance
  ↓
Outputs: Public IP + PEM Key
  ↓
Updates GitHub Secrets in THIS repo via GitHub API
  ↓
This workflow uses updated secrets to deploy
```

### Initial Setup

#### 1. Set Static Secrets (One-Time)

These don't change when you recreate the instance:

```bash
# Via GitHub CLI
gh secret set EC2_USER -b "ubuntu"
gh secret set DEPLOY_PATH -b "/home/ubuntu/on-prem-k8s"
```

Or manually in GitHub:
- Repository → Settings → Secrets → New repository secret
- `EC2_USER`: `ubuntu`
- `DEPLOY_PATH`: `/home/ubuntu/on-prem-k8s`

#### 2. Configure Infrastructure Repo to Update Secrets

In your infrastructure repository, after creating the EC2 instance, update the secrets:

**Using GitHub CLI:**

```bash
# After EC2 creation in your infrastructure repo
gh secret set EC2_HOST -b "$EC2_PUBLIC_IP" -R YOUR_USERNAME/on-prem-k8s
gh secret set EC2_SSH_PRIVATE_KEY -b "$EC2_PRIVATE_KEY" -R YOUR_USERNAME/on-prem-k8s
```

**Using GitHub API:**

```bash
# Get your GitHub token from settings
GITHUB_TOKEN="your_personal_access_token"
REPO_OWNER="YOUR_USERNAME"
REPO_NAME="on-prem-k8s"

# Update EC2_HOST
curl -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/actions/secrets/EC2_HOST \
  -d "{\"encrypted_value\":\"$ENCRYPTED_VALUE\",\"key_id\":\"$KEY_ID\"}"
```

**Using Terraform:**

```hcl
# In your infrastructure repo's Terraform
resource "github_actions_secret" "ec2_host" {
  repository       = "on-prem-k8s"
  secret_name      = "EC2_HOST"
  plaintext_value  = aws_instance.k8s_host.public_ip
}

resource "github_actions_secret" "ec2_ssh_key" {
  repository       = "on-prem-k8s"
  secret_name      = "EC2_SSH_PRIVATE_KEY"
  plaintext_value  = tls_private_key.k8s_ssh.private_key_pem
}
```

### What the Workflow Does

1. **Triggers** on push to `master` branch
2. **Reads secrets** (EC2_HOST, EC2_SSH_PRIVATE_KEY)
3. **Connects** to EC2 via SSH
4. **Clones** the repository (if first time) or **pulls** latest changes
5. **Displays** current commit information

### Testing the Workflow

```bash
# Make a change
echo "# Test deployment" >> README.md
git add README.md
git commit -m "Test deployment workflow"
git push origin master

# Check workflow status
# Go to: GitHub → Actions tab
```

### Manual Testing (Without Infrastructure Repo)

For initial testing, you can manually set the secrets:

```bash
# Display your EC2 instance PEM key
cat path/to/your-key.pem

# Set secrets via GitHub CLI
gh secret set EC2_SSH_PRIVATE_KEY < path/to/your-key.pem
gh secret set EC2_HOST -b "16.174.10.6"
gh secret set EC2_USER -b "ubuntu"
gh secret set DEPLOY_PATH -b "/home/ubuntu/on-prem-k8s"
```

### GitHub Personal Access Token Setup

For your infrastructure repo to update secrets here, create a token:

1. GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token (classic)
3. Name: "Infrastructure Repo - Update Secrets"
4. Scopes: Select `repo` (full control)
5. Copy the token
6. Add to infrastructure repo as secret: `GH_SECRETS_TOKEN`

### Workflow Status Badge

Add this to your README.md:

```markdown
[![Deploy to EC2](https://github.com/YOUR_USERNAME/on-prem-k8s/actions/workflows/deploy.yml/badge.svg)](https://github.com/YOUR_USERNAME/on-prem-k8s/actions/workflows/deploy.yml)
```

### Troubleshooting

**Connection refused:**
- Check EC2 security group allows SSH (port 22) from GitHub Actions IPs
- GitHub Actions IP ranges: https://api.github.com/meta (check `actions` field)
- Or allow SSH from anywhere (0.0.0.0/0) for testing

**Permission denied:**
- Verify the correct PEM key is stored in `EC2_SSH_PRIVATE_KEY` secret
- Check PEM key format includes header/footer:
  ```
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
  ```

**Secrets not updated:**
- Verify infrastructure repo has correct GitHub token with `repo` scope
- Check token hasn't expired
- Verify repository name is correct in infrastructure code

**Git command fails:**
- Ensure Git is installed on EC2: `sudo apt-get install git`
- Verify deploy path exists or parent directory is writable

### Automated Workflow

Your complete setup flow:

```
1. Infrastructure Repo: terraform apply
   ↓
2. EC2 instance created with new IP and PEM key
   ↓
3. Terraform updates GitHub secrets in this repo
   ↓
4. Push code to master in this repo
   ↓
5. GitHub Actions deploys using updated secrets
   ↓
6. Code deployed to new EC2 instance
```

### Security Notes

- **Private keys** should NEVER be committed to any repository
- **GitHub Secrets** are encrypted and only exposed during workflow execution
- **Personal Access Tokens** should have minimal required scopes
- Rotate tokens and keys periodically
- Consider using **GitHub Self-Hosted Runners** on your EC2 for even better security
- Use **least privilege** - infrastructure repo token only needs `repo` scope for this repo
