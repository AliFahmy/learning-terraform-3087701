data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}


module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "blog" {
  ami           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
  count = 1

  vpc_security_group_ids = [module.blog_sg.security_group_id]
  subnet_id = module.blog_vpc.public_subnets[0]
  tags = {
    Name = "HelloWorld"
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name    = "blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  target_groups = {
    blog-instance = {
      name_prefix      = "blog"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = aws_instance.blog[count.index].id
    }
  }

  tags = {
    Environment = "dev"
  }
}


resource "aws_lb_target_group" "blog_tg" {
  name = "blog-target-group"
  port = 80
  protocol = "HTTP"
  vpc_id = module.blog_vpc.vpc_id
  target_type = "instance"
}
resource "aws_lb_listener" "blog_alb_listener" {
 load_balancer_arn = module.alb.arn
 port              = "80"
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.blog_tg.arn
 }
}

resource "aws_lb_target_group_attachment" "blog-tg-attachement" {
  count = length(aws_instance.blog)
  target_group_arn = aws_lb_target_group.blog_tg.arn
  target_id = aws_instance.blog[count.index].id
}


module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"
  name= "blog"
  vpc_id = module.blog_vpc.vpc_id
  
  ingress_rules = ["http-80-tcp","https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}
