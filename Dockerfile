# For reproducible builds, consider pinning to a specific digest instead of `stable`.
# See https://github.com/foundry-rs/foundry/pkgs/container/foundry.
FROM ghcr.io/foundry-rs/foundry:stable

# Switch to the root user to install the necessary packages.
USER root

# Install `curl` and `jq` using the package manager.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        jq \
    && rm -rf /var/lib/apt/lists/*

# Copy the script into the image.
COPY ./safe_hashes.sh /app/safe_hashes.sh
RUN chmod +x /app/safe_hashes.sh

# Switch back to the default, non-root Foundry user for security.
USER foundry
