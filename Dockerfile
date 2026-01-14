FROM eclipse-temurin:25-jdk

# Install required tools
RUN apt-get update && \
    apt-get install -y curl screen && \
    rm -rf /var/lib/apt/lists/*

# Create /etc/machine-id as a file (required for mount)
RUN rm -rf /etc/machine-id && touch /etc/machine-id

# Create server directory and set as workdir
WORKDIR /server/Server

# Copy server files (must be downloaded first with ./hytale.sh install)
COPY Server/ ./
COPY Assets.zip ./Assets.zip

# Create necessary directories
RUN mkdir -p ../universe/worlds ../mods ../backups ../logs

# Copy and set entrypoint script
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose UDP port for Hytale
EXPOSE 5520/udp

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "HytaleServer.jar" || exit 1

# Set default JVM memory (optimized for 11GB RAM, overridden by docker-compose)
ENV XMS=4G
ENV XMX=8G

# Use entrypoint script
ENTRYPOINT ["/docker-entrypoint.sh"]
