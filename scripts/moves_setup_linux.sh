#!/usr/bin/bash

# Enhanced MOVES Setup Script for Linux
# This script installs and configures EPA MOVES on Ubuntu/Debian systems

set -e # Exit on any error

echo "Starting MOVES installation and configuration..."

# Install required packages
echo "Installing required packages..."
sudo apt update
sudo apt install openjdk-17-jdk mariadb-server mariadb-client golang-go ant gfortran git unzip dos2unix build-essential -y

# Add moves user to mariadb (user: moves, password: moves)
echo "Configuring MariaDB users..."
sudo mysql -u root -e "
-- Create user 'moves' with password 'moves'
CREATE USER IF NOT EXISTS 'moves'@'localhost' IDENTIFIED BY 'moves';
-- Grant all privileges to the moves user
GRANT ALL PRIVILEGES ON *.* TO 'moves'@'localhost' WITH GRANT OPTION;
-- Also create user for any host (if needed)
CREATE USER IF NOT EXISTS 'moves'@'%' IDENTIFIED BY 'moves';
GRANT ALL PRIVILEGES ON *.* TO 'moves'@'%' WITH GRANT OPTION;
-- Reload privileges
FLUSH PRIVILEGES;
"

# Configure mariadb
echo "Configuring MariaDB for MOVES..."
sudo tee /etc/mysql/mariadb.conf.d/50-server.cnf <<EOF
[mysqld]
default-storage-engine=MyISAM
lower_case_table_names=1
secure-file-priv=''
sql_mode=STRICT_TRANS_TABLES,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
init-connect='SET NAMES utf8mb4'
max_allowed_packet=2G
key_buffer_size=2G
query_cache_size=512M
table_open_cache=4000
myisam_sort_buffer_size=256M
bulk_insert_buffer_size=256M
tmp_table_size=1G
max_heap_table_size=1G
read_buffer_size=2M
myisam_repair_threads=4
concurrent_insert=2
EOF

# Restart MariaDB
echo "Restarting MariaDB..."
sudo systemctl restart mariadb
sudo systemctl enable mariadb

# Create user group
echo "Setting up user groups..."
sudo groupadd -f movesgroup

# Add current user and 'mysql' to movesgroup
sudo usermod -aG movesgroup $USER
sudo usermod -aG movesgroup mysql

# Set environment variables (Updated for Java 17)
echo "Setting up environment variables..."
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$PATH:/usr/bin/go
export ANT_HOME=/usr/share/ant
export PATH=$PATH:$ANT_HOME/bin

# Create permanent environment variables
sudo tee /etc/profile.d/moves.sh <<EOF
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANT_HOME=/usr/share/ant
export PATH=\$PATH:\$ANT_HOME/bin:/usr/bin/go
EOF

# Create temporary working directory in user space
echo "Setting up temporary workspace..."
TEMP_MOVES_DIR="$HOME/moves_temp_install"
rm -rf "$TEMP_MOVES_DIR"
mkdir -p "$TEMP_MOVES_DIR"
cd "$TEMP_MOVES_DIR"

# Clone EPA MOVES to user directory first
echo "Cloning EPA MOVES repository to user workspace..."
git clone https://github.com/USEPA/EPA_MOVES_Model.git
cd EPA_MOVES_Model

# Build MOVES (in user space)
echo "Building MOVES components..."
ant clean
ant compileall
ant go64

# Compile the external generator for Linux
echo "Compiling external generator for Linux..."
cd generators
go build -o externalgenerator64 externalgenerator.go
echo "External generator compiled successfully"
cd ..

# Compile the external calculator for Linux
echo "Compiling external calculator for Linux..."
cd calc
go build -o externalcalculatorgo64 externalcalculatorgo.go
echo "External calculator compiled successfully"
cd ..

# Compile Nonroad
if [ -d "NONROAD/NR08a/SOURCE" ]; then
  echo "Compiling Nonroad component..."
  cd NONROAD/NR08a
  # Remove existing NONROAD.exe if it exists
  [ -f "NONROAD.exe" ] && rm NONROAD.exe
  cd SOURCE
  if make; then
    if [ -f "nonroad.exe" ]; then
      mv nonroad.exe ../NONROAD.exe
      echo "Nonroad component compiled successfully"
    else
      echo "Error: Nonroad executable not found after compilation"
    fi
  else
    echo "Error: Nonroad compilation failed"
  fi
  cd ../../..
else
  echo "Warning: Nonroad source directory does not exist, skipping Nonroad compilation"
fi

# ========================================
# LINUX CONFIGURATION FIXES (in user space)
# ========================================

echo "Applying Linux configuration fixes..."

# Function to safely convert and edit files
fix_config_file() {
  local file="$1"
  local description="$2"

  if [ -f "$file" ]; then
    echo "Fixing $file..."

    # Convert line endings safely
    if command -v dos2unix >/dev/null 2>&1; then
      dos2unix "$file" 2>/dev/null || {
        # If dos2unix fails, use sed as fallback
        sed -i 's/\r$//' "$file"
      }
    else
      # Use sed if dos2unix not available
      sed -i 's/\r$//' "$file"
    fi

    # Apply specific fixes based on file type
    case "$file" in
    *WorkerConfiguration.txt | *manyworkers.txt)
      sed -i 's|calculatorApplicationPath = calc/externalcalculatorgo64\.exe|calculatorApplicationPath = calc/externalcalculatorgo64|g' "$file"
      ;;
    *maketodo.txt)
      sed -i 's|generatorExePath = generators/externalgenerator64\.exe|generatorExePath = generators/externalgenerator64|g' "$file"
      ;;
    *MOVESConfiguration.txt | *MOVESWorker.txt)
      sed -i 's|generatorExePath = generators\\externalgenerator64\.exe|generatorExePath = generators/externalgenerator64|g' "$file"
      sed -i 's|nonroadApplicationPath = NONROAD\\NR08a\\NONROAD\.exe|nonroadApplicationPath = NONROAD/NR08a/NONROAD.exe|g' "$file"
      sed -i 's|calculatorApplicationPath = calc/externalcalculatorgo64\.exe|calculatorApplicationPath = calc/externalcalculatorgo64|g' "$file"
      ;;
    esac

    # Convert all backslashes to forward slashes
    sed -i 's|\\|/|g' "$file"

    # Convert database names to lowercase
    sed -i 's/defaultDatabaseName=\([^[:space:]]*\)/defaultDatabaseName=\L\1/g' "$file"
    sed -i 's/outputDatabaseName=\([^[:space:]]*\)/outputDatabaseName=\L\1/g' "$file"
    sed -i 's/workerDatabaseName=\([^[:space:]]*\)/workerDatabaseName=\L\1/g' "$file"

    echo "Updated $description"
  else
    echo "Warning: $file not found"
  fi
}

# Fix all configuration files
fix_config_file "WorkerConfiguration.txt" "Worker Configuration"
fix_config_file "manyworkers.txt" "Many Workers Configuration"
fix_config_file "maketodo.txt" "Make Todo Configuration"
fix_config_file "MOVESConfiguration.txt" "MOVES Configuration"
fix_config_file "MOVESWorker.txt" "MOVES Worker Configuration"

echo "Linux configuration fixes completed."

# Fix path separators in configuration files
echo "Fixing path separators in configuration files..."

# Fix MOVESConfiguration.txt
if [ -f "MOVESConfiguration.txt" ]; then
  echo "Updating MOVESConfiguration.txt..."
  # Convert Windows line endings to Unix
  dos2unix MOVESConfiguration.txt

  # Replace specific Windows paths with Linux paths
  sed -i 's|generatorExePath = generators\\externalgenerator64\.exe|generatorExePath = generators/externalgenerator64|g' MOVESConfiguration.txt
  sed -i 's|nonroadApplicationPath = NONROAD\\NR08a\\NONROAD\.exe|nonroadApplicationPath = NONROAD/NR08a/NONROAD.exe|g' MOVESConfiguration.txt

  # Replace all remaining backslashes with forward slashes
  sed -i 's|\\|/|g' MOVESConfiguration.txt

  # Convert database names to lowercase
  sed -i 's/defaultDatabaseName=\([^[:space:]]*\)/defaultDatabaseName=\L\1/g' MOVESConfiguration.txt
  sed -i 's/outputDatabaseName=\([^[:space:]]*\)/outputDatabaseName=\L\1/g' MOVESConfiguration.txt

  echo "MOVESConfiguration.txt updated successfully"
else
  echo "Warning: MOVESConfiguration.txt not found"
fi

# Fix MOVESWorker.txt
if [ -f "MOVESWorker.txt" ]; then
  echo "Updating MOVESWorker.txt..."
  dos2unix MOVESWorker.txt

  # Replace specific Windows paths with Linux paths
  sed -i 's|generatorExePath = generators\\externalgenerator64\.exe|generatorExePath = generators/externalgenerator64|g' MOVESWorker.txt
  sed -i 's|nonroadApplicationPath = NONROAD\\NR08a\\NONROAD\.exe|nonroadApplicationPath = NONROAD/NR08a/NONROAD.exe|g' MOVESWorker.txt

  # Replace all remaining backslashes with forward slashes
  sed -i 's|\\|/|g' MOVESWorker.txt

  # Convert database names to lowercase
  sed -i 's/workerDatabaseName=\([^[:space:]]*\)/workerDatabaseName=\L\1/g' MOVESWorker.txt

  echo "MOVESWorker.txt updated successfully"
fi

# Fix manyworkers.txt (additional fixes beyond the specific one above)
if [ -f "manyworkers.txt" ]; then
  echo "Updating manyworkers.txt (additional fixes)..."
  dos2unix manyworkers.txt

  # Replace specific Windows paths with Linux paths (beyond calculator path already fixed)
  sed -i 's|generatorExePath = generators\\externalgenerator64\.exe|generatorExePath = generators/externalgenerator64|g' manyworkers.txt
  sed -i 's|nonroadApplicationPath = NONROAD\\NR08a\\NONROAD\.exe|nonroadApplicationPath = NONROAD/NR08a/NONROAD.exe|g' manyworkers.txt

  # Replace all remaining backslashes with forward slashes
  sed -i 's|\\|/|g' manyworkers.txt

  echo "manyworkers.txt updated successfully"
fi

# Fix maketodo.txt (additional fixes beyond the specific one above)
if [ -f "maketodo.txt" ]; then
  echo "Updating maketodo.txt (additional fixes)..."
  dos2unix maketodo.txt

  # Replace specific Windows paths with Linux paths (beyond generator path already fixed)
  sed -i 's|nonroadApplicationPath = NONROAD\\NR08a\\NONROAD\.exe|nonroadApplicationPath = NONROAD/NR08a/NONROAD.exe|g' maketodo.txt

  # Replace all remaining backslashes with forward slashes
  sed -i 's|\\|/|g' maketodo.txt

  echo "maketodo.txt updated successfully"
fi

# Create setenv.sh script for Linux environment
echo "Creating Linux environment setup script..."
cat >setenv.sh <<'EOF'
#!/bin/bash
# Linux environment setup for MOVES

export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANT_HOME=/usr/share/ant
export PATH=$PATH:$ANT_HOME/bin:/usr/bin/go

# Add current directory to classpath
export CLASSPATH=.:$CLASSPATH

# Set umask for proper permissions
umask 002

echo "MOVES environment configured for Linux"
echo "Java Home: $JAVA_HOME"
echo "Ant Home: $ANT_HOME" 
echo "Go available: $(which go)"
EOF

chmod +x setenv.sh

# ========================================
# MOVE TO SYSTEM LOCATION (/opt/moves)
# ========================================

echo "Moving MOVES to system location..."

# Create the system directory
sudo mkdir -p /opt/moves

# Remove any existing installation
if [ -d "/opt/moves/EPA_MOVES_Model" ]; then
  echo "Removing existing installation..."
  sudo rm -rf /opt/moves/EPA_MOVES_Model
fi

# Move the configured installation from user space to system location
sudo mv "$TEMP_MOVES_DIR/EPA_MOVES_Model" /opt/moves/

# Set proper ownership and permissions
sudo chown -R $USER:movesgroup /opt/moves/EPA_MOVES_Model
sudo chmod -R 775 /opt/moves/EPA_MOVES_Model
# Ensure both user and mysql can write to the directory
sudo chmod g+s /opt/moves/EPA_MOVES_Model
# Verify mysql is in movesgroup
sudo usermod -aG movesgroup mysql

echo "MOVES moved to /opt/moves/EPA_MOVES_Model"

# Change to the final installation directory
cd /opt/moves/EPA_MOVES_Model

# Setup default database
echo "Setting up MOVES default database..."
cd database/Setup

# Check if database zip file exists and extract it
if [ -f "movesdb20241112.zip" ]; then
  echo "Extracting default database..."
  unzip -o movesdb20241112.zip
elif [ -f "*.zip" ]; then
  echo "Found database zip file, extracting..."
  unzip -o *.zip
else
  echo "Warning: No database zip file found in Setup directory"
  echo "You may need to download the database manually"
fi

# Create and import database if SQL file exists
if [ -f "movesdb20241112.sql" ]; then
  echo "Creating MOVES database..."
  mysql -u moves -pmoves -e "CREATE DATABASE IF NOT EXISTS movesdb20241112;"

  echo "Importing MOVES default database (this may take several minutes)..."
  mysql -u moves -pmoves movesdb20241112 <movesdb20241112.sql
  echo "Database import completed successfully"
elif [ -f "*.sql" ]; then
  # Handle different SQL file names
  SQL_FILE=$(ls *.sql | head -n 1)
  DB_NAME=$(basename "$SQL_FILE" .sql)
  echo "Creating database: $DB_NAME"
  mysql -u moves -pmoves -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
  echo "Importing database from $SQL_FILE..."
  mysql -u moves -pmoves "$DB_NAME" <"$SQL_FILE"
  echo "Database import completed successfully"
else
  echo "Warning: No SQL file found for database import"
fi

# Create launcher scripts
echo "Creating launcher scripts..."
cd /opt/moves/EPA_MOVES_Model

# Create command line launcher template
cat >launch_moves_cli.sh <<'EOF'
#!/bin/bash
# Command line MOVES launcher
# Usage: ./launch_moves_cli.sh [runspec_file]

cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <runspec_file.mrs>"
    echo "Example: $0 /path/to/your/runspec.mrs"
    exit 1
fi

RUNSPEC="$1"
RUNSPEC_DIR=$(dirname "$RUNSPEC")
RUNSPEC_BASENAME=$(basename "$RUNSPEC" .MRS)
LOG_FILE="$RUNSPEC_DIR/${RUNSPEC_BASENAME}.log"

if [ ! -f "$RUNSPEC" ]; then
    echo "Error: Runspec file '$RUNSPEC' not found"
    exit 1
fi

echo "Running MOVES with runspec: $RUNSPEC"
echo "Log file: $LOG_FILE"

# Extract output database name from MRS file
OUTPUT_DB=$(grep -i "outputdatabase" "$RUNSPEC" | head -1 | sed 's/.*databasename="\([^"]*\)".*/\1/' | tr '[:upper:]' '[:lower:]')

if [ -z "$OUTPUT_DB" ]; then
    echo "Warning: Could not find output database name in MRS file"
    OUTPUT_DB="${RUNSPEC_BASENAME}_output"
fi

echo "Output database: $OUTPUT_DB"

# Run MOVES
ant run -Drunspec="$RUNSPEC" -Dmaxworkers=4 2>&1 | tee "$LOG_FILE"

# Check if MOVES run was successful and dump the output database
if [ $? -eq 0 ]; then
    echo "MOVES run completed successfully. Dumping output database..."
    DUMP_FILE="$RUNSPEC_DIR/${RUNSPEC_BASENAME}_output.sql"
    mysqldump -u moves -pmoves "$OUTPUT_DB" > "$DUMP_FILE"
    if [ $? -eq 0 ]; then
        echo "Database dump saved to: $DUMP_FILE"
    else
        echo "Warning: Failed to dump database $OUTPUT_DB"
    fi
else
    echo "MOVES run failed. Skipping database dump."
fi
EOF

chmod +x launch_moves_cli.sh

# Create multi-worker launcher for batch processing
cat >launch_moves_batch.sh <<'EOF'
#!/bin/bash
# Batch MOVES launcher with multiple workers
# Usage: ./launch_moves_batch.sh <mrs_directory> [max_workers]

cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh

if [ $# -lt 1 ]; then
    echo "Usage: $0 <mrs_directory> [max_workers]"
    echo "Example: $0 /path/to/mrs/files/ 7"
    exit 1
fi

MRS_DIR="$1"
MAX_WORKERS="${2:-4}"

if [ ! -d "$MRS_DIR" ]; then
    echo "Error: Directory '$MRS_DIR' not found"
    exit 1
fi

echo "Starting batch processing with $MAX_WORKERS workers..."
echo "Processing MRS files from: $MRS_DIR"

# Start additional workers
ant manyworkers -Dmaxworkers=$MAX_WORKERS -Dnoshutdown=1 &
WORKERS_PID=$!

# Process each MRS file
for MRS_FILE in "$MRS_DIR"/*.MRS "$MRS_DIR"/*.mrs; do
    if [ -f "$MRS_FILE" ]; then
        echo "Processing: $MRS_FILE"
        BASENAME=$(basename "$MRS_FILE" .MRS)
        BASENAME=$(basename "$BASENAME" .mrs)
        LOG_FILE="$HOME/${BASENAME}_log.txt"
        
        ant run -Drunspec="$MRS_FILE" >> "$LOG_FILE" 2>&1
    fi
done

# Stop workers
kill $WORKERS_PID 2>/dev/null || true

echo "Batch processing completed!"
EOF

chmod +x launch_moves_batch.sh

# Final setup and cleanup
echo "Performing final setup and cleanup..."
cd /opt/moves/EPA_MOVES_Model

# Ensure all shell scripts are executable
find . -name "*.sh" -exec chmod +x {} \;

# Set final permissions (already done, but ensuring consistency)
sudo chown -R $USER:movesgroup /opt/moves/EPA_MOVES_Model
sudo chmod -R 775 /opt/moves/EPA_MOVES_Model
sudo chmod g+s /opt/moves/EPA_MOVES_Model

# Clean up temporary installation directory
echo "Cleaning up temporary files..."
rm -rf "$TEMP_MOVES_DIR"

# Verify compiled executables exist
echo "Verifying compiled executables..."
if [ -f "generators/externalgenerator64" ]; then
  echo "External generator compiled successfully"
else
  echo "Error: External generator not found"
fi

if [ -f "calc/externalcalculatorgo64" ]; then
  echo "External calculator compiled successfully"
else
  echo "Error: External calculator not found"
fi

if [ -f "NONROAD/NR08a/NONROAD.exe" ]; then
  echo "Nonroad executable found"
else
  echo "Error: Nonroad executable not found"
fi

echo ""
echo "=========================================="
echo "MOVES installation completed successfully!"
echo "=========================================="
echo ""
echo "Available launchers:"
echo "  Command Line:   ./launch_moves_cli.sh <runspec.mrs>"
echo "  Batch Mode:     ./launch_moves_batch.sh <mrs_directory> [workers]"
echo ""
echo "Environment setup script: /opt/moves/EPA_MOVES_Model/setenv.sh"
echo "Configuration files have been updated for Linux paths"
echo ""
echo "Database Information:"
echo "- Host: localhost"
echo "- User: moves"
echo "- Password: moves"
echo "- Default Database: movesdb20241112 (or latest available)"
echo ""
echo "Common commands:"
echo "  cd /opt/moves/EPA_MOVES_Model"
echo "  source ./setenv.sh"
echo "  ./launch_moves_cli.sh <runspec.mrs>  # Run command line"
echo ""
echo "Note: You may need to log out and log back in for group changes to take effect"
echo "When copying input databases to mariadb, use:"
echo "  sudo cp -r input_database_path /var/lib/mysql/"
echo "  sudo chown -R mysql:mysql /var/lib/mysql/input_database_path"
echo "  sudo chmod -R 700 /var/lib/mysql/input_database_path"
