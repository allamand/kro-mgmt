# First, save the trust policy to a file named trust-policy.json
cat << 'EOF' > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/argocd-hub-role"
      },
      "Action": [
        "sts:TagSession",
        "sts:AssumeRole"
      ]
    }
  ]
}
EOF

# Replace MANAGEMENT_ACCOUNT_ID with your actual account ID
sed -i "s/MANAGEMENT_ACCOUNT_ID/382076407153/" trust-policy.json

# Create the IAM role
aws iam create-role \
    --role-name workload-cluster1-argocd-role \
    --description "Role for ArgoCD workload-cluster1" \
    --assume-role-policy-document file://trust-policy.json
