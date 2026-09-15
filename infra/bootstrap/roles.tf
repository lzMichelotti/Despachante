resource "aws_iam_role" "ci_plan" {
  name = "despachante-shared-ci-plan"

  # Trust policy: who may wear this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # Only a pull request run. A push to main cannot produce this subject.
          "token.actions.githubusercontent.com:sub" = "repo:lzMichelotti@190966483/Despachante@1352870260:pull_request"
        }
      }
    }]
  })

  tags = {
    Component = "ci"
  }
}


# plan reads every resource to compare code against reality.
resource "aws_iam_role_policy_attachment" "ci_plan_read" {
  role       = aws_iam_role.ci_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# plan is not purely read-only: it takes the state lock, and with use_lockfile
# the lock is an object in the state bucket.
resource "aws_iam_role_policy" "ci_plan_state_lock" {
  name = "state-lock"
  role = aws_iam_role.ci_plan.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      Resource = "${aws_s3_bucket.state.arn}/*.tflock"
    }]
  })
}

resource "aws_iam_role" "ci_apply" {
  name = "despachante-shared-ci-apply"

  # Trust policy: who may wear this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "sts:AssumeRoleWithWebIdentity"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          # A list is an OR. Note what is absent: :pull_request.
          "token.actions.githubusercontent.com:sub" = [
            "repo:lzMichelotti@190966483/Despachante@1352870260:ref:refs/heads/main",
            "repo:lzMichelotti@190966483/Despachante@1352870260:environment:prod",
          ]
        }
      }
    }]
  })

  tags = {
    Component = "ci"
  }
}

resource "aws_iam_role_policy_attachment" "ci_apply_admin" {
  role       = aws_iam_role.ci_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Guardrail for the admin policy above. Deny beats Allow in IAM, always.
# apply may build the whole project, but never touch the foundation that
# grants it access, and never mint a static credential.
resource "aws_iam_role_policy" "ci_apply_guardrail" {
  name = "foundation-guardrail"
  role = aws_iam_role.ci_apply.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # The state bucket itself. Reading and writing state objects stays allowed.
        Sid    = "ProtectStateBucket"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
        ]
        Resource = aws_s3_bucket.state.arn
      },
      {
        # Without this, a compromised apply rewrites its own trust policy
        # and turns a one-run compromise into permanent access.
        Sid    = "ProtectCiRoles"
        Effect = "Deny"
        Action = [
          "iam:UpdateAssumeRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:UpdateRole",
          "iam:DeleteRole",
        ]
        Resource = [
          aws_iam_role.ci_plan.arn,
          aws_iam_role.ci_apply.arn,
        ]
      },
      {
        Sid    = "ProtectOidcProvider"
        Effect = "Deny"
        Action = [
          "iam:UpdateOpenIDConnectProviderThumbprint",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
          "iam:DeleteOpenIDConnectProvider",
        ]
        Resource = aws_iam_openid_connect_provider.github.arn
      },
      {
        # Enforces the project rule "no static credentials" in IAM, not just in docs.
        Sid    = "NoStaticCredentials"
        Effect = "Deny"
        Action = [
          "iam:CreateUser",
          "iam:CreateAccessKey",
          "iam:CreateLoginProfile",
          "iam:UpdateAccessKey",
        ]
        Resource = "*"
      },
    ]
  })
}
