
variable "vpc_cidr" {

    type = string
    description = "Public VPC CIDR values"
    default = "10.0.0.0/16"
}

variable "cidr_public_subnet" {

    type = list(string)
    description = "Public Subnet CIDR values"
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "cidr_private_subnet" {

    type = list(string)
    description = "Private Subnet CIDR values"
    default = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "cidr_db_private_subnet" {

    type = list(string)
    description = "Private Subnets CIDR values for DB"
    default = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "ap_northeast_availability_zone" {

    type = list(string)
    description = "Availability Zones"
    default = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "name" {

    type = list(string)
    description = "Distinguish between a and c"
    default = ["a", "c"]
}

variable "key_name" {
  type = string
  default = "terraform-asm4"
  description = "key name of ec2"
}
