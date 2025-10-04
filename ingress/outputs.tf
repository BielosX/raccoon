output "listener_arn" {
  value = aws_lb_listener.listener.arn
}

output "alb_arn" {
  value = aws_lb.alb.arn
}

output "domain" {
  value = module.distribution.domain
}