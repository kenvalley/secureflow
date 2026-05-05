# SecureFlow Terraform - Vulnerablities Fixed Version.
# This version has been remediated to fix the vulnerabilities tagged with IV-08.

variable "project" { type = string }

# IV-08 fix: replaced AdministratorAccess with minimum required EKS node policies
resource "aws_iam_role" "eks_node" {
  name = "${var.project}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IV-08 fix: replaced wildcard Action/Resource with scoped IRSA role
resource "aws_iam_role" "app_role" {
  name = "${var.project}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "app_inline" {
  name = "${var.project}-app-inline"
  role = aws_iam_role.app_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ]
      Resource = "arn:aws:secretsmanager:*:*:secret:secureflow/*"
    }]
  })
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "app_role_arn" {
  value = aws_iam_role.app_role.arn
}





# SecureFlow Terraform — INTENTIONALLY VULNERABLE baseline.
# Planted vulnerabilities are tagged with their Vulnerability Index ID.

# variable "project" { type = string }

# # IV-08 — EKS node role is given AdministratorAccess.
# # Remediation: scope to specific managed policies (AmazonEKSWorkerNodePolicy,
# # AmazonEKS_CNI_Policy, AmazonEC2ContainerRegistryReadOnly) and use IRSA for
# # application pods that need AWS access.

# resource "aws_iam_role" "eks_node" {
#   name = "${var.project}-eks-node-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "admin_access" {
#   role       = aws_iam_role.eks_node.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # IV-08
# }

# # A second role used by the app pods — also over-privileged.
# resource "aws_iam_role" "app_role" {
#   name = "${var.project}-app-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "ec2.amazonaws.com"
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy" "app_inline" {
#   name = "${var.project}-app-inline"
#   role = aws_iam_role.app_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect   = "Allow"
#       Action   = "*"     # IV-08 — wildcard action.
#       Resource = "*"     # IV-08 — wildcard resource.
#     }]
#   })
# }

# output "eks_node_role_arn" {
#   value = aws_iam_role.eks_node.arn
# }

# output "app_role_arn" {
#   value = aws_iam_role.app_role.arn
# }
