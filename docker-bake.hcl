variable "IMAGE" {
  default = "docker-certbot-dns-ionos"
}

variable "VERSION" {
  default = "2024.11.09"
}

variable "IMAGE_VERSION" {
  default = "2026.07.16"
}

variable "CERTBOT_VERSION" {
  default = "v5.7.0"
}

variable "GOLANG_VERSION" {
  default = "1.26.5-alpine"
}

variable "SUPERCRONIC_VERSION" {
  default = "v0.2.47"
}

variable "USER_UID" {
  default = "1000"
}

variable "USER_GID" {
  default = "1000"
}

target "default" {
  dockerfile = "Dockerfile"
  args = {
    VERSION              = VERSION
    IMAGE_VERSION        = IMAGE_VERSION
    CERTBOT_VERSION      = CERTBOT_VERSION
    GOLANG_VERSION       = GOLANG_VERSION
    SUPERCRONIC_VERSION  = SUPERCRONIC_VERSION
    USER_UID             = USER_UID
    USER_GID             = USER_GID
  }
  platforms = ["linux/amd64", "linux/arm64", "linux/arm/v6"]
  tags = ["${IMAGE}:${IMAGE_VERSION}"]
}
