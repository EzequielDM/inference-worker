# --- STAGE 1: Compile your custom fork ---
FROM nvidia/cuda:12.2.0-devel-ubuntu22.04 AS builder
RUN apt-get update && apt-get install -y git build-essential cmake

# Pull your modified repository
RUN git clone https://github.com/EzequielDM/llama.cpp-bad /llama.cpp
WORKDIR /llama.cpp

# Compile the server binary with CUDA support
RUN mkdir build && cd build && \
    cmake .. -DGGML_CUDA=ON \
             -DCMAKE_CUDA_ARCHITECTURES="80;86;89;90" && \
    cmake --build . --config Release -j $(nproc)

# --- STAGE 2: Set up the inference-worker environment ---
FROM nvidia/cuda:12.2.0-runtime-ubuntu22.04

# --- STAGE 3: Inject the custom binary ---
# This overwrites the default server with your reverse-engineered/modified version
COPY --from=builder /llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

# Set the working directory to something neutral
WORKDIR /app

# Copy the local 'src' folder INTO a folder named 'src' in the container
COPY src /src

# Install Python and the dependencies required by the worker repo
RUN apt-get update && apt-get install -y python3 python3-pip
COPY requirements.txt .
RUN pip3 install -r requirements.txt

# Update your CMD to point to the correct absolute path
CMD ["python3", "-u", "/src/handler.py"]
