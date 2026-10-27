FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git make g++ autoconf flex bison help2man python3 \
    libfl-dev zlib1g-dev liblz4-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/riscv \
    && curl -fsSL --retry 3 \
    'https://drive.syntacore.com/s/8Atb2bcYjZS8eHE/download?files=sc-dt-2023.11.tar.gz&path=%2F2023%2F2023.11' \
    | tar -xz -C /opt/riscv --strip-components=2 sc-dt/riscv-gcc

RUN git clone --depth 1 --branch v5.052 https://github.com/verilator/verilator.git /tmp/verilator \
    && cd /tmp/verilator \
    && autoconf && ./configure \
    && make -j4 && make install \
    && rm -rf /tmp/verilator

ENV PATH="/opt/riscv/bin:${PATH}"
WORKDIR /work
CMD ["make"]
