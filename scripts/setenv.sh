#!/bin/bash
# /opt/moves/setenv.sh - Linux equivalent of setenv.bat

# Set JAVA_HOME if not already set
if [ -z "$JAVA_HOME" ]; then
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
fi

# Set MOVES home directory
export MOVES_HOME=/opt/moves

# Add Java to PATH
export PATH=$JAVA_HOME/bin:$PATH

# Set ANT_HOME
export ANT_HOME=/usr/share/ant
export PATH=$ANT_HOME/bin:$PATH

# Set database connection parameters
export MOVES_DB_SERVER=localhost
export MOVES_DB_PORT=3306
export MOVES_DB_USER=moves
export MOVES_DB_PASSWORD=moves

# Set memory options for Java
export JAVA_OPTS="-Xmx4g -Xms1g -XX:+UseG1GC"
export ANT_OPTS="$JAVA_OPTS"

# Set locale
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

# Print environment info
echo "MOVES Environment Setup"
echo "======================"
echo "JAVA_HOME: $JAVA_HOME"
echo "MOVES_HOME: $MOVES_HOME"
echo "ANT_HOME: $ANT_HOME"
echo "Database Server: $MOVES_DB_SERVER:$MOVES_DB_PORT"
echo "Java Version: $(java -version 2>&1 | head -n 1)"
echo "Ant Version: $(ant -version 2>&1 | head -n 1)"
echo "======================"