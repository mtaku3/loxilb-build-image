# Download base image ubuntu 20.04 for build
FROM ubuntu:22.04 as build

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive

ARG TAG=main

ARG EXTRA_CFLAGS=""

# Env variables
ENV PATH="${PATH}:/usr/local/go/bin"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/lib64/"

RUN mkdir -p /root/loxilb-io/loxilb
COPY . /root/loxilb-io/loxilb/

# Create directories
RUN mkdir -p /opt/loxilb \
    /usr/lib64/ \
    /opt/loxilb/cert/ \
    /etc/loxilb/certs/ \
    /etc/bash_completion.d/

# Update repository and install wget
RUN apt-get update && apt-get install -y wget

# Detect architecture and install arch-specific tools
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    echo $arch && \
    if [ "$arch" = "arm64" ]; then \
        cpus="1" && apt-get install -y gcc-arm-linux-gnueabihf; \
    else \
        cpus=$(nproc) && apt-get update && apt-get install -y gcc-multilib; \
    fi

# Install Go
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    wget https://go.dev/dl/go1.23.0.linux-${arch}.tar.gz && \
    tar -xzf go1.23.0.linux-${arch}.tar.gz --directory /usr/local/ && \
    rm go1.23.0.linux-${arch}.tar.gz

# Install development and utility packages
RUN apt-get install -y clang-14 llvm libelf-dev libpcap-dev vim net-tools ca-certificates \
    elfutils dwarves git libbsd-dev bridge-utils wget unzip build-essential \
    bison flex sudo iproute2 pkg-config tcpdump iputils-ping curl bash-completion

# Install OpenSSL 3.4.1
RUN wget https://github.com/openssl/openssl/releases/download/openssl-3.4.1/openssl-3.4.1.tar.gz && \
    tar -xvzf openssl-3.4.1.tar.gz && \
    cd openssl-3.4.1 && ./Configure enable-ktls '-Wl,-rpath,$(LIBRPATH)' --prefix=/usr/local/build && \
    make -j$(nproc) && make install_dev install_modules && \
    cd - && cp -a /usr/local/build/include/openssl /usr/include/ && \
    if [ -d /usr/local/build/lib64 ]; then mv /usr/local/build/lib64 /usr/local/build/lib; fi && \
    cp -fr /usr/local/build/lib/* /usr/lib/ && ldconfig && \
    rm -fr openssl-3.4.1*

# Install bpftool
RUN wget https://github.com/libbpf/bpftool/releases/download/v7.2.0/bpftool-libbpf-v7.2.0-sources.tar.gz && \
    tar -xvzf bpftool-libbpf-v7.2.0-sources.tar.gz && \
    cd bpftool/src/ && make clean && make -j$(nproc) && \
    cp -f ./bpftool /usr/local/sbin/bpftool && \
    cd - && rm -fr bpftool*

# Install loxicmd
RUN git clone https://github.com/loxilb-io/loxicmd.git && \
    cd loxicmd && git fetch --all --tags && git checkout $TAG && \
    go get . && make && \
    cp ./loxicmd /usr/local/sbin/loxicmd && \
    cd - && rm -fr loxicmd

# Enable bash completion for loxicmd
RUN /usr/local/sbin/loxicmd completion bash > /etc/bash_completion.d/loxi_completion

# Install loxilb
RUN cd /root/loxilb-io/loxilb/ && \
    # git fetch --all --tags && \
    # git checkout $TAG && \
    cd loxilb-ebpf && \
    git fetch --all --tags && \
    git checkout $TAG && \
    cd .. && \
    go get . && \
    arch=$(arch | sed 's/aarch64/arm64/' | sed 's/x86_64/amd64/') && \
    if [ "$arch" = "arm64" ]; then \
        DOCKER_BUILDX_ARM64=true make build EXTRA_CFLAGS="${EXTRA_CFLAGS}"; \
    else \
        make build EXTRA_CFLAGS="${EXTRA_CFLAGS}"; \
    fi && \
    cp loxilb-ebpf/utils/mkllb_bpffs.sh /usr/local/sbin/mkllb_bpffs && \
    cp tools/k8s/mkllb-url /usr/local/sbin/mkllb-url && \
    cp loxilb-ebpf/utils/mkllb_cgroup.sh /usr/local/sbin/mkllb_cgroup && \
    cp loxilb-ebpf/kernel/loxilb_dp_debug /usr/local/sbin/loxilb_dp_debug && \
    cp /root/loxilb-io/loxilb/loxilb /usr/local/sbin/loxilb && \
    rm -rf /root/loxilb-io/loxilb/* \
           /root/loxilb-io/loxilb/.git \
           /root/loxilb-io/loxilb/.github && \
    mkdir -p /root/loxilb-io/loxilb/ && \
    cp /usr/local/sbin/loxilb /root/loxilb-io/loxilb/loxilb && \
    rm /usr/local/sbin/loxilb

# Install gobgp
RUN arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    wget https://github.com/osrg/gobgp/releases/download/v3.29.0/gobgp_3.29.0_linux_${arch}.tar.gz && \
    tar -xzf gobgp_3.29.0_linux_${arch}.tar.gz && rm gobgp_3.29.0_linux_${arch}.tar.gz && \
    mv gobgp* /usr/sbin/ && rm -f LICENSE README.md

# Clean up unnecessary packages
RUN apt-get purge -y clang-14 llvm libelf-dev libpcap-dev libbsd-dev build-essential \
    elfutils dwarves git bison flex wget unzip && \
    apt-get -y autoremove && apt-get install -y libllvm14 && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) && \
    if [ "$arch" = "arm64" ]; then apt purge -y gcc-arm-linux-gnueabihf; else apt-get purge -y gcc-multilib; fi && \
    rm -rf /var/lib/apt/lists/* && apt clean

# Enable bash completion globally
RUN echo "if [ -f /etc/bash_completion ] && ! shopt -oq posix; then" >> /root/.bashrc && \
    echo "    . /etc/bash_completion" >> /root/.bashrc && \
    echo "fi" >> /root/.bashrc

# Optional files, only apply when files exist
# COPY ./loxilb.rep* /root/loxilb-io/loxilb/loxilb
# COPY ./llb_ebpf_main.o.rep* /opt/loxilb/llb_ebpf_main.o
# COPY ./llb_xdp_main.o.rep* /opt/loxilb/llb_xdp_main.o

FROM ubuntu:22.04

# LABEL about the loxilb image
LABEL description="loxilb official docker image"

# Disable Prompt During Packages Installation
ARG DEBIAN_FRONTEND=noninteractive

# Env variables
ENV PATH="${PATH}:/usr/local/go/bin"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:/usr/lib64/"

RUN apt-get update && apt-get install -y --no-install-recommends sudo wget \
    libbsd-dev iproute2 tcpdump bridge-utils net-tools libllvm14 ca-certificates && \
    rm -rf /var/lib/apt/lists/* && apt clean

COPY --from=build /usr/lib64/libbpf* /usr/lib64/
COPY --from=build /usr/local/build/lib/* /usr/lib64
COPY --from=build /usr/local/go/bin /usr/local/go/bin
COPY --from=build /usr/local/sbin/mkllb_bpffs /usr/local/sbin/mkllb_bpffs
COPY --from=build /usr/local/sbin/mkllb-url /usr/local/sbin/mkllb-url
COPY --from=build /usr/local/sbin/mkllb_cgroup /usr/local/sbin/mkllb_cgroup
COPY --from=build /usr/local/sbin/loxilb_dp_debug /usr/local/sbin/loxilb_dp_debug
COPY --from=build /usr/local/sbin/loxicmd /usr/local/sbin/loxicmd
COPY --from=build /opt/loxilb /opt/loxilb
COPY --from=build /root/loxilb-io/loxilb/loxilb /root/loxilb-io/loxilb/loxilb
COPY --from=build /usr/local/sbin/bpftool /usr/local/sbin/bpftool
COPY --from=build /usr/sbin/gobgp* /usr/sbin/
COPY --from=build /root/.bashrc /root/.bashrc

ENTRYPOINT ["/root/loxilb-io/loxilb/loxilb"]

# Expose Ports
EXPOSE 11111 22222 3784
