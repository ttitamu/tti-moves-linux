FROM debian:bookworm-slim

LABEL maintainer="TTI TAMU"
LABEL description="EPA MOVES Model for Linux - Dockerized"
LABEL version="1.0"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV ANT_HOME=/usr/share/ant
ENV PATH=$PATH:$ANT_HOME/bin:/usr/bin/go
ENV CLASSPATH=.:$CLASSPATH

# Install required packages
RUN apt-get update && apt-get install -y \
    openjdk-17-jdk \
    mariadb-server \
    mariadb-client \
    golang-go \
    ant \
    gfortran \
    git \
    unzip \
    dos2unix \
    build-essential \
    sudo \
    curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure MariaDB for MOVES
COPY mariadb-moves.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Create workspace directory
WORKDIR /opt/moves

# Copy setup script and make it executable
COPY setup-moves-docker.sh /tmp/setup-moves-docker.sh
RUN chmod +x /tmp/setup-moves-docker.sh

# Set up MOVES environment (as root)
RUN /tmp/setup-moves-docker.sh

# Create moves user and group
RUN groupadd -r movesgroup && \
    useradd -r -g movesgroup -m -s /bin/bash moves && \
    usermod -aG sudo moves && \
    echo "moves ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Add mysql to movesgroup
RUN usermod -aG movesgroup mysql

# Change ownership of MOVES installation to moves user
RUN chown -R moves:movesgroup /opt/moves

# Create startup script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose MariaDB port
EXPOSE 3306

# Set working directory to MOVES installation
WORKDIR /opt/moves/EPA_MOVES_Model

# Switch to moves user for runtime
USER moves

# Entry point
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["bash"]