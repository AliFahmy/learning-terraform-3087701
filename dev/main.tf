module "dev" {
  source = "../modules/blog"

  environment = {
    name           = "dev"
    network_prefix = "10.0"
  }
  min_size = 1
  max_size = 2
}
