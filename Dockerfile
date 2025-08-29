# Use official Ubuntu 22.04 image as base
FROM ubuntu:22.04

# Set environment variable to avoid issues in non-interactive mode
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install necessary dependencies
COPY config/debian.sources /etc/apt/sources.list.d/debian.sources

RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y build-essential
RUN apt-get install -y libssl-dev
RUN apt-get install -y pkg-config
RUN apt-get install -y git
RUN apt-get install -y ca-certificates
RUN apt-get install -y software-properties-common
RUN apt-get install -y apt-transport-https

RUN rm -rf /var/lib/apt/lists/*

# Install Rustup (for installing Rust and Cargo)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add Cargo's bin directory to PATH
ENV PATH="/root/.cargo/bin:${PATH}"

# Install Foundryup (Foundry installer)
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="/root/.foundry/bin:${PATH}"
RUN foundryup

# Set working directory
RUN mkdir /app
WORKDIR /app

# (Optional) Expose port if you plan to run network services in the container
EXPOSE 8545

# Default command when container starts (adjust as needed)
CMD ["/bin/bash"]
