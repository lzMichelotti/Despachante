resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # client_id_list is the token's `aud`, despite the name.
  client_id_list = ["sts.amazonaws.com"]

  # No thumbprint_list: AWS validates GitHub's cert against its own trusted root CAs.

  tags = {
    Component = "oidc"
  }
}
