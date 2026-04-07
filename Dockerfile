# --- STAGE 1: Build your custom llama.cpp ---
FROM nvidia/cuda:13.0.0-devel-ubuntu22.04 AS builder

RUN apt-get update && apt-get install -y git build-essential cmake

RUN git clone https://github.com/EzequielDM/llama.cpp-bad /llama.cpp
WORKDIR /llama.cpp

# Target the specific architectures for AMPERE_48 (86) and ADA_32_PRO (89)
RUN mkdir build && cd build && \
    cmake .. -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="80;86;89;90;100;120" && \
    cmake --build . --config Release -j $(nproc)

# --- STAGE 2: The actual RunPod Runtime ---
# We use the runtime image to keep it lean
FROM nvidia/cuda:13.0.0-runtime-ubuntu22.04

ENV PYTHONUNBUFFERED=1

# Replicating the project's specific python3.11 setup
RUN apt-get update --yes --quiet && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    software-properties-common gpg-agent build-essential apt-utils ca-certificates curl git && \
    add-apt-repository --yes ppa:deadsnakes/ppa && apt update --yes --quiet && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    python3.11 python3.11-dev python3.11-distutils bash && \
    ln -s /usr/bin/python3.11 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Inject your custom binary into the standard path
COPY --from=builder /llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

# Match the project's folder logic
WORKDIR /work

# ADDing ./src to /work. 
# This works if your requirements.txt is inside the 'src' folder.
ADD ./src /work

# Install dependencies from the now-moved requirements file
RUN pip install -r ./requirements.txt && chmod +x /work/start.sh

ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
