# loxilb-build-image

> **Archived / unmaintained.** I no longer use this. Kept for reference.

Custom Dockerfile and GitHub Actions workflow to build [loxilb](https://github.com/loxilb-io/loxilb) and [kube-loxilb](https://github.com/loxilb-io/kube-loxilb) images with extra datapath compile flags, then push to Docker Hub.

## What's here

- `loxilb.Dockerfile` — replacement Dockerfile for the upstream loxilb repo. Builds on Ubuntu 22.04, installs Go 1.23, OpenSSL 3.4.1, clang-14, and compiles loxilb with custom `CFLAGS_ALL`.
- `.github/workflows/build-and-push.yaml` — manual (`workflow_dispatch`) workflow with three jobs:
  - `loxilb` — release image, tag `<TAG>`.
  - `loxilb-debug` — adds `-DHAVE_DP_LOG_LVL_TRACE`, tag `<TAG>-debug`.
  - `kube-loxilb` — upstream `kube-loxilb` image, tag `<TAG>`.

## Custom datapath flags

```
-DHAVE_DP_FC=1
-DHAVE_DP_EXTCT=1
-DHAVE_DP_SCTP_SUM=1
-DHAVE_DP_CT_SYNC=1
-DMAX_REAL_CPUS=16
-DHAVE_DP_RSS=1
-DHAVE_DP_PERSIST_TFC=1
-DHAVE_DP_FW=1
```

## Usage

Required repo settings:

- Variable `DOCKERHUB_USERNAME`
- Secret `DOCKERHUB_TOKEN`

Trigger via Actions → *Build and push* → Run workflow, supply `TAG` (a loxilb / kube-loxilb git ref).

## License

Apache-2.0. See `LICENSE`.
