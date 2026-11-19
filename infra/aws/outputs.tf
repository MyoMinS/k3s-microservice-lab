output "public_ip" { value = aws_eip.k3s.public_ip }
output "instance_id" { value = aws_instance.k3s.id }
#output "dog_ecr_repository_url" { value = aws_ecr_repository.dog.repository_url }
#output "cat_ecr_repository_url" { value = aws_ecr_repository.cat.repository_url }
#output "aws_account_id" { value = data.aws_caller_identity.current.account_id }
#output "github_actions_role_arn" { value = var.github_repository == "" ? null : aws_iam_role.github_actions[0].arn }