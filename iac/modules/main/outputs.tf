# #------------------------------------------------------------------------------
# # sfn_state_machine.tf
# #------------------------------------------------------------------------------

# resource "aws_ssm_parameter" "sfn_state_machine_arn" {
#   name  = "${local.output_prefix}/sfn_state_machine_arn"
#   type  = "String"
#   value = aws_sfn_state_machine.step_fn.arn
# }
