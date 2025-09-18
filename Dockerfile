# Use an official Ubuntu base image
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && \
    apt-get install -y \
    bash \
    curl \
    jq \
    git \
    ca-certificates \
    build-essential && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -s /bin/bash safeuser

# Set working directory
WORKDIR /app

# Copy the script and make it executable
COPY safe_hashes.sh /app/safe_hashes.sh
RUN chmod +x /app/safe_hashes.sh

# Switch to non-root user
USER safeuser

# Install Foundry as the non-root user
ENV PATH="/home/safeuser/.foundry/bin:${PATH}"

# Install Foundry in the user's home directory
RUN curl -L https://foundry.paradigm.xyz | bash && \
    /home/safeuser/.foundry/bin/foundryup && \
    # Verify installation
    /home/safeuser/.foundry/bin/cast --version && \
    /home/safeuser/.foundry/bin/chisel --version

# Set bash as the default shell
SHELL ["/bin/bash", "-c"]

# Default entrypoint
ENTRYPOINT ["/app/safe_hashes.sh"]
