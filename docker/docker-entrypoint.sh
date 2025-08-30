#!/bin/bash

# Docker entrypoint script for MOVES
set -e

echo "Starting MOVES Docker container..."

# Start MariaDB service
echo "Starting MariaDB service..."
sudo service mariadb start

# Wait for MariaDB to be ready
echo "Waiting for MariaDB to be ready..."
until sudo mysqladmin ping >/dev/null 2>&1; do
  echo -n "."
  sleep 1
done
echo " MariaDB is ready!"

# Configure MariaDB users (only if not already configured)
if ! mysql -u moves -pmoves -e "SELECT 1" >/dev/null 2>&1; then
  echo "Configuring MariaDB users..."
  sudo mysql -u root -e "
    CREATE USER IF NOT EXISTS 'moves'@'localhost' IDENTIFIED BY 'moves';
    GRANT ALL PRIVILEGES ON *.* TO 'moves'@'localhost' WITH GRANT OPTION;
    CREATE USER IF NOT EXISTS 'moves'@'%' IDENTIFIED BY 'moves';
    GRANT ALL PRIVILEGES ON *.* TO 'moves'@'%' WITH GRANT OPTION;
    FLUSH PRIVILEGES;
  "
  echo "MariaDB users configured successfully!"
else
  echo "MariaDB users already configured."
fi

# Set up default database if not exists
cd /opt/moves/EPA_MOVES_Model/database/Setup
if [ -f "movesdb20241112.zip" ] && ! mysql -u moves -pmoves -e "USE movesdb20241112;" >/dev/null 2>&1; then
  echo "Setting up default MOVES database..."
  
  # Extract database if needed
  if [ ! -f "movesdb20241112.sql" ]; then
    echo "Extracting database..."
    unzip -o movesdb20241112.zip
  fi
  
  # Create and import database
  if [ -f "movesdb20241112.sql" ]; then
    echo "Creating database..."
    mysql -u moves -pmoves -e "CREATE DATABASE IF NOT EXISTS movesdb20241112;"
    
    echo "Importing database (this may take several minutes)..."
    mysql -u moves -pmoves movesdb20241112 < movesdb20241112.sql
    echo "Database imported successfully!"
  fi
elif mysql -u moves -pmoves -e "USE movesdb20241112;" >/dev/null 2>&1; then
  echo "Default database already exists."
else
  echo "Warning: Default database setup files not found. You may need to set up the database manually."
fi

# Go back to MOVES directory
cd /opt/moves/EPA_MOVES_Model

# Source environment
source ./setenv.sh

echo ""
echo "================================================"
echo "MOVES Docker Container is ready!"
echo "================================================"
echo ""
echo "Available commands:"
echo "  ./launch_moves_cli.sh /opt/moves/data/runspec.mrs  # Run MOVES with runspec"
echo ""
echo "Database Information:"
echo "  Host: localhost"
echo "  User: moves"
echo "  Password: moves"
echo "  Default Database: movesdb20241112"
echo ""
echo "Mount your data directory to /opt/moves/data for easy access:"
echo "  docker run -v /host/data:/opt/moves/data moves-image"
echo ""

# Execute the command passed to the container
exec "$@"