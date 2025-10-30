group "default" {
  # targets = ["loxilb", "loxilb-debug", "kube-loxilb"]
  targets = ["loxilb", "kube-loxilb"]
}

variable "TAG" {}
variable "DOCKERHUB_USERNAME" {}

target "loxilb" {
  dockerfile = "loxilb.Dockerfile"
  contexts = {
    src = "https://github.com/loxilb-io/loxilb.git#${TAG}"
  }
  args = {
    TAG = TAG
    BUILDKIT_CONTEXT_KEEP_GIT_DIR = "1"
  }
  tags = ["docker.io/${DOCKERHUB_USERNAME}/loxilb:${TAG}"]
}

# target "loxilb-debug" {
#   inherits = ["loxilb"]
#   args = {
#     TAG = TAG
#     EXTRA_CFLAGS = "-DHAVE_DP_LOG_LVL_TRACE"
#   }
#   tags = ["docker.io/${DOCKERHUB_USERNAME}/loxilb:${TAG}-debug"]
# }

target "kube-loxilb" {
  context = "https://github.com/loxilb-io/kube-loxilb.git#${TAG}"
  args = {
    BUILDKIT_CONTEXT_KEEP_GIT_DIR = "1"
  }
  tags = ["docker.io/${DOCKERHUB_USERNAME}/kube-loxilb:${TAG}"]
}
