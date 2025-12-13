# module/shared-alb/outputs.tf

# We need these to connect the ECS module later
output "alb_arn" { value = aws_lb.main.arn }
output "listener_arn" { value = aws_lb_listener.http.arn }
output "security_group_id" { value = aws_security_group.lb_sg.id }

# Inside modules/shared-alb/outputs.tf
output "dns_name" {
  value = aws_lb.main.dns_name
}