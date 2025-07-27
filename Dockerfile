# Dockerfile for GTA-Style Multiplayer Game Server
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Download Godot headless (4.4.1 stable)
RUN wget https://downloads.tuxfamily.org/godotengine/4.4.1/Godot_v4.4.1-stable_linux.x86_64.zip \
    && unzip Godot_v4.4.1-stable_linux.x86_64.zip \
    && mv Godot_v4.4.1-stable_linux.x86_64 /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm Godot_v4.4.1-stable_linux.x86_64.zip

# Create app directory
WORKDIR /app

# Copy game files (will be populated by build export)
COPY Builds/server/ /app/

# Create non-root user for security
RUN useradd -m -u 1000 gameserver && chown -R gameserver:gameserver /app
USER gameserver

# Expose port (Railway sets $PORT environment variable)
EXPOSE $PORT

# Health check - simple process check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep godot || exit 1

# Run the headless server
CMD godot --headless --server --port ${PORT:-8080} 