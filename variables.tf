variable "VPC_name" {
    type = "string"
    description= "Nom du VPC"
}

variable "VPC_CIDR" {
    type = "string"
    description= "CIDR du VPC"
}

variable "AZS" {
    description = "Listes des zones de disponibilités"
    type = "list"
}