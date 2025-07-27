# Simple Dockerfile for Railway deployment
FROM ubuntu:22.04

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    libc6 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy our game server executable
COPY game-server /app/3d-game-server

# Make sure it's executable
RUN chmod +x /app/3d-game-server

# Railway handles port routing automatically

# Debug: Add startup logging
CMD echo "Container starting..." && \
    echo "PORT environment variable: $PORT" && \
    echo "Executable permissions:" && \
    ls -la /app/3d-game-server && \
    echo "Starting server on port ${PORT:-8080}..." && \
    /app/3d-game-server --headless --server --port ${PORT:-8080} 