variable "prefix" {
  type = string
}

variable "env" {
  type = string
}

variable "iot_topic" {
  type = string
}

variable "alert_email" {
  type    = string
  default = "cet11group1@gmail.com"
}

variable "temperature_min" {
  type    = number
  default = 25
}

variable "temperature_max" {
  type    = number
  default = 60
}

variable "humidity_min" {
  type    = number
  default = 40
}

variable "humidity_max" {
  type    = number
  default = 90
}

variable "pressure_min" {
  type    = number
  default = 990
}

variable "pressure_max" {
  type    = number
  default = 1050
}

variable "battery_min" {
  type    = number
  default = 40
}

variable "battery_max" {
  type    = number
  default = 100
}
