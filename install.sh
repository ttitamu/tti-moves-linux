#!/bin/bash

# EPA MOVES Debian Installer
# Simple installer that clones repository and runs setup
# Usage: curl -sSL https://raw.githubusercontent.com/ttitamu/tti-moves-linux/main/install.sh | bash

set -e

REPO_URL="https://github.com/ttitamu/tti-moves-linux.git"
INSTALL_DIR="$HOME/EPA-MOVES-Linux"

echo "==========================================="
echo "EPA MOVES Debian Installer"
echo "==========================================="
echo

# Check if running on Debian system
if ! command -v apt-get &> /dev/null; then
    echo "Error: This installer is designed for Debian systems only."
    echo "Please ensure you are running on a Debian-based distribution."
    exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "Error: Please do not run this script as root."
    echo "The script will ask for sudo permissions when needed."
    exit 1
fi

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: git is required but not installed."
    echo "Installing git..."
    sudo apt update && sudo apt install git -y
fi

# Remove existing directory if it exists
if [ -d "$INSTALL_DIR" ]; then
    echo "Removing existing EPA-MOVES-Linux directory..."
    rm -rf "$INSTALL_DIR"
fi

# Clone the repository
echo "Cloning EPA MOVES Linux repository..."
git clone "$REPO_URL" "$INSTALL_DIR"

# Enter directory and run installation
echo "Starting MOVES installation..."
cd "$INSTALL_DIR"
chmod +x scripts/moves_setup_linux.sh
sudo bash scripts/moves_setup_linux.sh

echo
echo "==========================================="
echo "EPA MOVES Installation Complete on Debian!"
echo "==========================================="
echo
echo "MOVES has been installed to: /opt/moves/EPA_MOVES_Model"
echo "Repository cloned to: $INSTALL_DIR"
echo
echo "To get started:"
echo "1. Open a new terminal (to load environment variables)"
echo "2. Navigate to MOVES directory: cd /opt/moves/EPA_MOVES_Model"
echo "3. Source the environment: source ./setenv.sh"
echo "4. Run command line: ./launch_moves_cli.sh /path/to/runspec.mrs"
echo
echo "For more information, visit: https://github.com/ttitamu/tti-moves-linux"
echo