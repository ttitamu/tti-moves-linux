# MOVES Docker Setup

This directory contains Docker configuration files to run EPA MOVES in a containerized environment.

## Quick Start

### Build and Run with Docker Compose (Recommended)

```bash
# Build and start the container
docker-compose up --build -d

# Access the container
docker-compose exec moves bash

# Run MOVES with a runspec file
./launch_moves_cli.sh /data/your_runspec.mrs
```

### Build and Run with Docker

```bash
# Build the image
docker build -t moves-linux .

# Run the container
docker run -it -v $(pwd)/data:/data moves-linux

# Inside container, run MOVES
./launch_moves_cli.sh /data/your_runspec.mrs
```

## Directory Structure

```
docker/
├── Dockerfile                 # Main Docker image definition
├── docker-compose.yml         # Docker Compose configuration
├── docker-entrypoint.sh      # Container startup script
├── setup-moves-docker.sh     # MOVES installation script
├── mariadb-moves.cnf         # MariaDB configuration
├── data/                     # Mount point for runspecs and outputs
├── input_databases/          # Mount point for input databases
└── config/                   # Mount point for custom configurations
```

## Volume Mounts

- `./data:/opt/moves/data` - Your runspec files and output results
- `./input_databases:/opt/moves/input_databases` - Input database files (read-only)
- `./config:/config` - Custom configuration files (read-only)
- `moves_db_data` - Persistent MariaDB data

## Environment Variables

- `JAVA_HOME` - Java installation path
- `ANT_HOME` - Apache Ant installation path
- `TZ` - Container timezone (default: America/Chicago)

## Resource Requirements

- **Memory**: 4-8GB recommended
- **CPU**: 2-4 cores recommended
- **Storage**: At least 10GB free space for databases

## Usage Examples

### Running a Single Runspec

```bash
# Place your runspec file in ./data/
cp your_runspec.mrs ./data/

# Start container and run MOVES
docker-compose up -d
docker-compose exec moves ./launch_moves_cli.sh /opt/moves/data/your_runspec.mrs
```

### Accessing the Database

MariaDB runs internally within the container with credentials:
- **Username**: moves
- **Password**: moves
- **Default Database**: movesdb20241112

```bash
# Connect from within container
docker-compose exec moves mysql -u moves -pmoves
```

## Troubleshooting

### Container won't start
- Check available disk space
- Ensure Docker has enough memory allocated (8GB+ recommended)
- Check logs: `docker-compose logs moves`

### Database import fails
- Ensure you have the database zip file in the correct location
- Check container logs for specific error messages
- Verify available disk space

### Permission issues
- The container runs as user `moves` (UID varies)
- Ensure mounted directories have proper permissions
- Use `docker-compose exec moves chown -R moves:movesgroup /data` if needed

## Advanced Configuration

### Using External MariaDB

Uncomment the `mariadb` service in `docker-compose.yml` to run MariaDB as a separate container.

### Custom Memory Settings

Modify the `deploy.resources` section in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      memory: 16G
      cpus: '8.0'
```

### Persistent Configuration

Mount a custom configuration directory:

```bash
# Create custom config
mkdir -p ./config
cp /path/to/custom/MOVESConfiguration.txt ./config/

# Container will use files from /config if available
```