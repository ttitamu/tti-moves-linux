#!/bin/bash

# MOVES Docker Setup Script
# This script sets up EPA MOVES inside the Docker container

set -e

echo "Starting MOVES Docker setup..."

# Create temporary working directory
TEMP_MOVES_DIR="/tmp/moves_install"
mkdir -p "$TEMP_MOVES_DIR"
cd "$TEMP_MOVES_DIR"

# Clone EPA MOVES repository
echo "Cloning EPA MOVES repository..."
git clone https://github.com/USEPA/EPA_MOVES_Model.git
cd EPA_MOVES_Model

# Build MOVES
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

# Apply Linux configuration fixes
echo "Applying Linux configuration fixes..."

fix_config_file() {
  local file="$1"
  
  if [ -f "$file" ]; then
    echo "Fixing $file..."
    
    # Convert line endings
    if command -v dos2unix >/dev/null 2>&1; then
      dos2unix "$file" 2>/dev/null || sed -i 's/\r$//' "$file"
    else
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
    
    echo "Updated $file"
  else
    echo "Warning: $file not found"
  fi
}

# Fix all configuration files
fix_config_file "WorkerConfiguration.txt"
fix_config_file "manyworkers.txt"
fix_config_file "maketodo.txt"
fix_config_file "MOVESConfiguration.txt"
fix_config_file "MOVESWorker.txt"

echo "Linux configuration fixes completed."

# Create setenv.sh script for Linux environment
echo "Creating Linux environment setup script..."
cat > setenv.sh << 'EOF'
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

# Move MOVES to final location
echo "Moving MOVES to /opt/moves..."
mkdir -p /opt/moves
mv "$TEMP_MOVES_DIR/EPA_MOVES_Model" /opt/moves/

# Set proper permissions (ownership will be set later in Dockerfile)
chmod -R 775 /opt/moves/EPA_MOVES_Model
chmod g+s /opt/moves/EPA_MOVES_Model

# Create launcher scripts
cd /opt/moves/EPA_MOVES_Model

# Create command line launcher
cat > launch_moves_cli.sh << 'EOF'
#!/bin/bash
# Command line MOVES launcher for Docker
# Usage: ./launch_moves_cli.sh [runspec_file]

cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <runspec_file.mrs>"
    echo "Example: $0 /data/runspec.mrs"
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

# Ensure all shell scripts are executable
find . -name "*.sh" -exec chmod +x {} \;

# Clean up temporary directory
rm -rf "$TEMP_MOVES_DIR"

echo "MOVES Docker setup completed successfully!"