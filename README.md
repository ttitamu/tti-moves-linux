# EPA MOVES for Linux

This is an unofficial repository for installing and running the EPA MOVES (Motor Vehicle Emission Simulator) on Debian-based Linux systems.

This repository provides a simple, automated installation of EPA MOVES 5.0 on Linux systems.

## Quick Installation

**One command installation:**

```bash
curl -sSL https://raw.githubusercontent.com/ttitamu/tti-moves-linux/main/install.sh | bash
```

**Manual installation:**

```bash
git clone https://github.com/ttitamu/tti-moves-linux.git
cd tti-moves-linux
sudo bash scripts/moves_setup_linux.sh
```

## What This Installs

- **EPA MOVES 5.0** - Latest version from EPA's official repository
- **MariaDB** - Database optimized for MOVES
- **Java 17** - Required runtime environment
- **Build tools** - Ant, Go, GFortran for compiling MOVES components
- **Linux compatibility fixes** - Path corrections and executable configurations

## System Requirements

- **OS**: Debian-based systems (Debian, Ubuntu, etc.)
- **Memory**: 8GB+ recommended (4GB minimum)
- **Storage**: 20GB+ free space
- **Network**: Internet connection for downloading components

## Installation Location

- **MOVES**: `/opt/moves/EPA_MOVES_Model`
- **Repository**: `~/EPA-MOVES-Linux` (when using curl installation)

## Usage

After installation:

```bash
# Navigate to MOVES directory
cd /opt/moves/EPA_MOVES_Model

# Source environment
source ./setenv.sh

# Run MOVES with a runspec file
./launch_moves_cli.sh /path/to/your/runspec.mrs

# Batch processing
./launch_moves_batch.sh /path/to/mrs/directory/
```

## Database Configuration

- **Host**: localhost
- **User**: moves
- **Password**: moves
- **Default Database**: movesdb20241112

## Output Files

When using `launch_moves_cli.sh`, output files are saved in the same directory as your MRS file:

- `runspec.log` - Execution log
- `runspec_output.sql` - Database dump of results

## Support

For issues and documentation, visit the project repository.

