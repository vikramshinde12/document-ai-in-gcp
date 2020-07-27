variable "project_name" {
   description = "The project ID where all resources will be launched."
  type = string
}

variable "region" {
  description = "The location region to deploy the Cloud IOT services. Note: Be sure to pick a region that supports Cloud IOT."
  type        = string
}

variable "zone" {
  description = "The location zone to deploy the Cloud IOT services. Note: Be sure to pick a region that supports Cloud IOT."
  type        = string
}