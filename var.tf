variable "project_id" {
  type = string
  default = "decisive-plasma-333810"
}

variable "region" {
  type = string 
  default = "asia-south1"
}

variable "zone" {
  type = string
  default = "asia-south1-a"
}                       

variable "image" {
  type = string
  default =  "asia-south1-docker.pkg.dev/tatvic-gcp-dev-team/auto-tagger/autotagger-image:4.0"
}

variable "creator" {
  type = string
  default =  "tatvic"
}

variable "org" {
  type = string
  default =  "tatvic"
}
