# EPA MOVES Installation Guide

This guide provides detailed instructions for installing EPA MOVES on Linux systems.

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 18.04+ or Debian 10+
- **Memory**: 8GB RAM minimum (16GB recommended for large datasets)
- **Storage**: 20GB+ free disk space
- **CPU**: Multi-core processor recommended
- **Network**: Internet connection for downloading packages and EPA MOVES repository

### User Permissions
- You must have `sudo` access on the target system
- Do not run the installer as root - it will request sudo when needed

## Installation Methods

### Method 1: One-Command Installation (Recommended)

The simplest way to install MOVES:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/HMP-MOVES-Linux/main/install.sh | bash
```

This command will:
1. Download the installation script from GitHub
2. Run the complete MOVES setup process
3. Configure all dependencies and environment variables
4. Create necessary user groups and permissions

### Method 2: Manual Installation

If you prefer to review the code before running or need to customize the installation:

```bash
# Clone the repository
git clone https://github.com/yourusername/HMP-MOVES-Linux.git
cd HMP-MOVES-Linux

# Review the installation script (optional)
less scripts/moves_setup_linux.sh

# Run the installation
sudo bash scripts/moves_setup_linux.sh
```

### Method 3: Docker Installation

For containerized deployment:

```bash
# Clone the repository
git clone https://github.com/yourusername/HMP-MOVES-Linux.git
cd HMP-MOVES-Linux/docker

# Build and start the container
docker-compose up -d

# Access the container
docker-compose exec moves5 bash
```

## Installation Process Details

The installation script performs these operations:

### 1. Package Installation
- **Java 17 OpenJDK** - Runtime environment for MOVES
- **MariaDB Server** - Database system optimized for MOVES
- **Build Tools** - ant, golang-go, gfortran, build-essential
- **Utilities** - git, unzip, dos2unix

### 2. User and Group Setup
- Creates `movesgroup` for shared access
- Adds current user and mysql user to movesgroup
- Configures proper umask for file permissions

### 3. MariaDB Configuration
- Optimizes MariaDB settings for MOVES workloads
- Creates `moves` database user with password `moves`
- Grants necessary privileges for MOVES operations
- Configures MyISAM storage engine (required by MOVES)

### 4. EPA MOVES Installation
- Clones latest MOVES from EPA's official GitHub repository
- Compiles Java components using Ant
- Builds Go-based external generator and calculator
- Compiles NONROAD component if available
- Applies Linux compatibility fixes

### 5. Configuration Fixes
- Converts Windows-style paths to Linux format
- Updates configuration files for Linux executables
- Fixes database name case sensitivity
- Creates environment setup script

### 6. Database Setup
- Imports default MOVES database if available
- Creates sample launcher scripts
- Configures proper file permissions

## Post-Installation Verification

After installation completes, verify the setup:

### 1. Check Installation Directory
```bash
ls -la /opt/moves/EPA_MOVES_Model
```

You should see the MOVES directory structure with proper permissions.

### 2. Verify Executables
```bash
cd /opt/moves/EPA_MOVES_Model
ls -la generators/externalgenerator64
ls -la calc/externalcalculatorgo64
```

Both files should exist and be executable.

### 3. Test Database Connection
```bash
mysql -u moves -pmoves -e "SHOW DATABASES;"
```

Should show the MOVES databases including the default database.

### 4. Test Environment Setup
```bash
cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh
echo $JAVA_HOME
```

Should display the Java installation path.

## Environment Configuration

The installer creates several environment configurations:

### System-wide Environment
- `/etc/profile.d/moves.sh` - System-wide environment variables
- Added to all user shells automatically

### User Environment
- `~/.bashrc` - User-specific configurations
- Includes umask settings for proper file permissions

### MOVES Environment
- `/opt/moves/EPA_MOVES_Model/setenv.sh` - MOVES-specific environment
- Must be sourced before running MOVES

## Troubleshooting Installation

### Common Issues

**1. Permission Denied Errors**
```bash
# Fix ownership
sudo chown -R $USER:movesgroup /opt/moves/EPA_MOVES_Model
sudo chmod -R 775 /opt/moves/EPA_MOVES_Model
```

**2. Java Not Found**
```bash
# Verify Java installation
java -version
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
```

**3. MariaDB Connection Issues**
```bash
# Restart MariaDB
sudo systemctl restart mariadb
sudo systemctl status mariadb

# Reset database user
sudo mysql -u root -e "DROP USER 'moves'@'localhost';"
sudo mysql -u root -e "CREATE USER 'moves'@'localhost' IDENTIFIED BY 'moves';"
sudo mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'moves'@'localhost';"
```

**4. Compilation Errors**
```bash
# Check build dependencies
sudo apt update
sudo apt install -y build-essential gfortran golang-go ant openjdk-17-jdk

# Re-run compilation
cd /opt/moves/EPA_MOVES_Model
ant clean
ant compileall
ant go64
```

### Log Files

Installation logs are displayed in real-time. For debugging:

- MariaDB logs: `/var/log/mysql/error.log`
- MOVES logs: Generated in `/opt/moves/EPA_MOVES_Model/` during runs
- System logs: `journalctl -u mariadb` for database issues

### Getting Help

If you encounter issues:
1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review the installation logs for specific error messages
3. Verify system requirements are met
4. Open an issue on the GitHub repository with:
   - Your operating system version
   - Error messages from the installation
   - Output of `java -version` and `mysql --version`

## Next Steps

After successful installation:
1. Read the [Usage Guide](USAGE.md) for running MOVES
2. Check the [examples/](../examples/) directory for sample files
3. Review MOVES documentation for creating runspec files

## Uninstallation

To remove MOVES and related components:

```bash
# Remove MOVES installation
sudo rm -rf /opt/moves

# Remove MariaDB (optional, if not used by other applications)
sudo apt remove --purge mariadb-server mariadb-client

# Remove environment configuration
sudo rm -f /etc/profile.d/moves.sh

# Remove user from movesgroup
sudo deluser $USER movesgroup
```

Note: This will remove all MOVES data and configurations. Back up any important data first.