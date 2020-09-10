# Cakely Vault and Runner Setup
> Vault and self hosted runner setup for cakely/api-ops and cakely/api

## About

Though GitHub Actions comes with an encrypted [secret store](https://help.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets), some users will prefer to keep secrets in [HashiCorp Vault](https://www.vaultproject.io/), either out of feature set comparison or convenience in already having secrets stored in Vault.

This repository provides instructions for replacing the Actions secret store with Vault by utilizing network-connected self-hosted runners. It contains Vault policies and AWS IAM policies for an "EKS / ECR Admin" self hosted runner (more privileged) and an "ECR Push" self hosted runner (less privileged).

![image](https://user-images.githubusercontent.com/2993937/90143755-fb805a00-dd4b-11ea-90bf-44a38210373d.png)

## Context

This repo is the technical complement to a webinar entitled Secure GitOps Workflows with GitHub Actions and HashiCorp Vault, delivered on August 25<sup>th</sup> 2020, which can be viewed online [**here**](https://www.hashicorp.com/resources/secure-gitops-workflows-with-github-actions-and-hashicorp-vault).

The work here represents the final state of the demos and workflows that were presented as a part of that webinar. It is recommended to view this repo in the context of that webinar.

You are here 🍰:
* [`cakely/api`](https://github.com/cakely/api)
* [`cakely/api-ops`](https://github.com/cakely/api-ops)
* **🍰 [`cakely/vault-runner-setup`](https://github.com/cakely/vault-runner-setup) 🍰 - Vault and self hosted runner setup for `cakely/api-ops` and `cakely/api`**

For more goodness related to cake, GitHub, and Terraform, kindly view the previous webinar entitled [Unlocking the Cloud Operating Model with GitHub Actions](https://www.hashicorp.com/resources/unlocking-the-cloud-operating-model-with-github-actions/).

## Pre-requisites

- AWS account
- New IAM user with [`superuser-iam-policy.json`](superuser-iam-policy.json) attached. Make note of the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`.

## Setup

#### Start Vault and set up AppRole auth method

<details><summary>Instructions</summary>

```bash
# Start up vault dev server if not already started
# Note: vault server -dev NOT recommended production
vault server -dev
export VAULT_ADDR='http://127.0.0.1:8200'

# Enable AppRole auth method
vault auth enable approle
```

</details>


#### 1️⃣ Self Hosted Runner "EKS / ECR Admin" (More Privileged)

![admin](https://user-images.githubusercontent.com/2993937/90151776-199e8800-dd55-11ea-9842-a6e6c67bde8b.png)

<details><summary>Instructions</summary>

```bash
############### EKS / ECR Admin ####################

# Generate a Personal Access Token with repo scope for eksctl deploy key, add it to Vaults
vault kv put secret/github/eksctlDeployKey pat=$PAT_FOR_DEPLOY_KEY
vault kv put secret/aws access_key=$AWS_ACCESS_KEY_ID secret_key=$AWS_SECRET_ACCESS_KEY

# Create EKS / ECR Admin policy (more privileged)
vault policy write eks-ecr-admin eks-ecr-admin.hcl

# Create EKS / ECR Admin role
vault write auth/approle/role/eks-ecr-admin token_policies="eks-ecr-admin"

# Get RoleID and SecretID for eks-ecr-admin role
vault read auth/approle/role/eks-ecr-admin/role-id
vault write -f auth/approle/role/eks-ecr-admin/secret-id

export ROLE_ID=role-id-from-above
export SECRET_ID=secret-id-from-above

#### Optional: Local test to see if we can read dynamic secrets using the AppRole token
vault write auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID
# This creates a temporary federated token
# Read how to use here: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html
VAULT_TOKEN=token vault write aws/sts/eks-ecr-admin ttl=30m
```

Now that your `ROLE_ID` and `SECRET_ID` are ready, it's time to add a self hosted runner. 

1. Create a [self hosted runner group for your organization](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups#creating-a-self-hosted-runner-group-for-an-organization) called EKS / ECR Admin. I made it available to the `cakely/api-ops` repository.
1. Add a [self hosted runner to your organization](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-an-organization). As you go through the prompts of `config.sh`, be sure to add it to the EKS / ECR Admin runner group.
1. Start your self hosted runner with `./run.sh`. I used the very same Terminal tab as I exported `ROLE_ID` and `SECRET_ID` above.

![terminal](https://user-images.githubusercontent.com/2993937/89962097-b952fd80-dc11-11ea-8ad8-9947a06cb6b4.png)

</details>


#### 2️⃣ Self Hosted Runner "ECR Push" (Less Privileged)

![ecr push](https://user-images.githubusercontent.com/2993937/90151984-4fdc0780-dd55-11ea-9b74-02e9724d803d.png)

<details><summary>Instructions</summary>

```bash
############### ECR Push ####################
# Enable AWS secrets engine
vault secrets enable -path=aws aws

# Configure AWS secrets engine with the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY 
# from `superuser-iam-policy.json` user
vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=my-region

# Create named Vault role with AWS IAM policy attached
vault write aws/roles/ecr-push \
    credential_type=federation_token \
    policy_document=@ecr-push-iam-policy.json

# Create ECR Push policy
vault policy write ecr-push ecr-push.hcl

# Create new ECR Push AppRole with ECR Push policy attached
vault write auth/approle/role/ecr-push token_policies="ecr-push"

# Get RoleID and SecretID for ecr-push role
vault read auth/approle/role/ecr-push/role-id
vault write -f auth/approle/role/ecr-push/secret-id

export ROLE_ID=role-id-from-above
export SECRET_ID=secret-id-from-above

#### Optional: Local test to see if we can read dynamic secrets using the AppRole token
vault write auth/approle/login role_id=$ROLE_ID secret_id=$SECRET_ID
# This creates a temporary federated token
# Read how to use here: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_temp.html
VAULT_TOKEN=token vault write aws/sts/ecr-push ttl=30m
```

Now that your `ROLE_ID` and `SECRET_ID` are ready, it's time to add another self hosted runner. 

1. Create a [self hosted runner group for your organization](https://docs.github.com/en/actions/hosting-your-own-runners/managing-access-to-self-hosted-runners-using-groups#creating-a-self-hosted-runner-group-for-an-organization) called ECR Push. I made it available to the `cakely/api-ops` repository.
1. Add a [self hosted runner to your organization](https://docs.github.com/en/actions/hosting-your-own-runners/adding-self-hosted-runners#adding-a-self-hosted-runner-to-an-organization). As you go through the prompts of `config.sh`, be sure to add it to the ECR Push runner group.
1. Start your self hosted runner with `./run.sh`. I used the very same Terminal tab as I exported `ROLE_ID` and `SECRET_ID` above.

![terminal](https://user-images.githubusercontent.com/2993937/89962070-a8a28780-dc11-11ea-86d2-529e969fbc4c.png)

</details>

## License

[MIT](LICENSE)

## Future improvements

- Replace manual setup steps for self hosted runner with two container images
- Leverage the [AWS Secrets Engine](https://www.vaultproject.io/docs/secrets/aws) in both cases.

## Credits

- https://www.vaultproject.io/docs/secrets/aws#usage
- https://learn.hashicorp.com/tutorials/vault/approle
- https://learn.hashicorp.com/tutorials/vault/getting-started-dynamic-secrets
