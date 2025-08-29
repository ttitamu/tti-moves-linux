# EPA MOVES Usage Guide

This guide covers how to use EPA MOVES after installation on Linux systems.

## Getting Started

### Environment Setup

Before running MOVES, always source the environment setup:

```bash
cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh
```

This sets up:
- Java classpath and JAVA_HOME
- Ant and Go paths
- MOVES-specific environment variables

### Verify Installation

Check that MOVES is ready:

```bash
cd /opt/moves/EPA_MOVES_Model

# Check executables
ls -la generators/externalgenerator64
ls -la calc/externalcalculatorgo64

# Test database connection
mysql -u moves -pmoves -e "SHOW DATABASES;"

# Test Java/Ant
ant -version
```

## Running MOVES

### GUI Mode

Launch the MOVES graphical interface:

```bash
cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh
ant crungui
```

**Note**: GUI mode requires X11 forwarding if using SSH. For remote servers, use command-line mode instead.

### Command Line Mode

#### Single Run

Run MOVES with a specific runspec file:

```bash
cd /opt/moves/EPA_MOVES_Model
source ./setenv.sh

# Using the provided launcher script
./launch_moves_cli.sh /path/to/runspec.mrs

# Or using ant directly
ant run -Drunspec="/path/to/runspec.mrs"
```

#### Batch Processing

Process multiple runspec files:

```bash
# Using the batch launcher
./launch_moves_batch.sh /path/to/mrs/directory/ 4

# Where:
# - /path/to/mrs/directory/ contains .MRS files
# - 4 is the number of worker processes
```

#### Custom Ant Commands

Advanced users can use ant directly:

```bash
# Run with specific parameters
ant run -Drunspec="runspec.mrs" -Dmaxworkers=8

# Run with debugging
ant run -Drunspec="runspec.mrs" -Ddebug=true

# Run with custom memory settings
export ANT_OPTS="-Xmx8g -Xms2g"
ant run -Drunspec="runspec.mrs"
```

## Working with Databases

### Default Database

The installation includes a default MOVES database. List available databases:

```bash
mysql -u moves -pmoves -e "SHOW DATABASES;"
```

### Input Databases

MOVES requires input databases for specific geographic areas and years. 

#### Import Input Database

**From SQL dump:**
```bash
mysql -u moves -pmoves -e "CREATE DATABASE your_input_db;"
mysql -u moves -pmoves your_input_db < input_database.sql
```

**From compressed file:**
```bash
# Extract and import
unzip input_database.zip
mysql -u moves -pmoves your_input_db < extracted_database.sql
```

#### Copy Database Files

For MariaDB binary files (.MYI, .MYD, .frm):

```bash
# Stop MariaDB
sudo systemctl stop mariadb

# Copy database files
sudo cp -r /path/to/database/ /var/lib/mysql/
sudo chown -R mysql:mysql /var/lib/mysql/database_name/
sudo chmod -R 700 /var/lib/mysql/database_name/

# Start MariaDB
sudo systemctl start mariadb
```

### Output Databases

MOVES creates output databases with results. To export:

```bash
# Export entire database
mysqldump -u moves -pmoves output_database > results.sql

# Export specific tables
mysqldump -u moves -pmoves output_database movesrun movesoutput > results.sql

# Compress large exports
mysqldump -u moves -pmoves output_database | gzip > results.sql.gz
```

## Runspec Files

### Understanding Runspec Files

Runspec (.mrs) files define:
- Geographic domain (county, state)
- Time periods (years, months, days, hours)
- Vehicle types and fuel types
- Pollutants to calculate
- Output database configuration

### Creating Runspec Files

**Option 1: Use MOVES GUI**
1. Launch GUI: `ant crungui`
2. Configure run parameters
3. Save as .mrs file

**Option 2: Edit Existing Runspec**
```bash
# Copy a sample runspec
cp examples/sample_runspecs/sample.mrs my_run.mrs

# Edit with text editor
nano my_run.mrs

# Key sections to modify:
# - <geographicBounds>
# - <timeSpan>
# - <vehicleTypes>
# - <fuelTypes>
# - <pollutantProcessAssoc>
# - <databaseSelection>
```

### Sample Runspec Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<runspec version="MOVES5.0.0">
  <description>My MOVES Run</description>
  
  <models>
    <model value="ONROAD"/>
  </models>
  
  <modelDomain value="COUNTY"/>
  
  <geographicBounds>
    <geographicBound type="COUNTY" key="48041" description="Ellis County, TX"/>
  </geographicBounds>
  
  <timeSpan>
    <year key="2020"/>
    <month id="1"/>
    <dayType id="5"/> <!-- Weekday -->
    <hour id="8"/>   <!-- 8 AM -->
  </timeSpan>
  
  <!-- More configuration... -->
</runspec>
```

## Performance Optimization

### Memory Settings

For large runs, increase Java memory:

```bash
export ANT_OPTS="-Xmx12g -Xms4g -XX:+UseG1GC"
ant run -Drunspec="large_runspec.mrs"
```

### Worker Processes

Use multiple workers for faster processing:

```bash
# Start additional workers
ant manyworkers -Dmaxworkers=6 -Dnoshutdown=1 &

# Run MOVES (in another terminal)
ant run -Drunspec="runspec.mrs"

# Stop workers when done
pkill -f "manyworkers"
```

### Database Optimization

**Optimize MariaDB for MOVES:**

```bash
# Edit MariaDB configuration
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Key settings for large datasets:
[mysqld]
key_buffer_size = 4G
tmp_table_size = 2G
max_heap_table_size = 2G
max_allowed_packet = 2G
```

**Monitor database performance:**

```bash
# Check database size
mysql -u moves -pmoves -e "SELECT table_schema, ROUND(SUM(data_length + index_length) / 1024 / 1024, 1) AS 'DB Size in MB' FROM information_schema.tables GROUP BY table_schema;"

# Monitor active processes
mysql -u moves -pmoves -e "SHOW PROCESSLIST;"
```

## Monitoring Runs

### Log Files

MOVES creates detailed log files:

```bash
# View real-time logs (if using launcher script)
tail -f ~/runspec_name.log

# Check for errors
grep -i error ~/runspec_name.log
grep -i exception ~/runspec_name.log
```

### Progress Monitoring

```bash
# Monitor database activity
watch "mysql -u moves -pmoves -e 'SHOW PROCESSLIST;'"

# Check temporary file creation
watch "ls -la MOVESTemporary/"

# Monitor system resources
htop
iotop  # I/O monitoring
```

### Estimating Runtime

Runtime depends on:
- **Domain size**: County vs. state vs. national
- **Time periods**: More years/months increase runtime
- **Vehicle/fuel types**: More types = longer runtime  
- **Pollutants**: More pollutants = longer runtime
- **Hardware**: CPU cores, RAM, disk I/O

**Typical runtimes:**
- Single county, single year, basic pollutants: 30-60 minutes
- State-level analysis: Several hours to days
- National analysis: Days to weeks

## Output Analysis

### Understanding Output

MOVES generates results in the output database:

**Key tables:**
- `movesrun` - Run metadata and parameters
- `movesoutput` - Emission results by pollutant, vehicle type, etc.
- `movesactivityoutput` - Activity data (VMT, trips, etc.)

### Export Results

```bash
# Export to CSV
mysql -u moves -pmoves -e "
SELECT * FROM movesoutput 
WHERE MOVESRunID = 1
" --batch --raw | sed 's/\t/,/g' > results.csv

# Export summary data
mysql -u moves -pmoves -e "
SELECT pollutantID, SUM(emissionQuant) as total_emissions
FROM movesoutput 
GROUP BY pollutantID
" output_database
```

### Visualization

Results can be analyzed with:
- **R** - Statistical analysis and plotting
- **Python pandas** - Data manipulation and analysis
- **Excel** - Basic analysis of exported CSV files
- **Tableau/Power BI** - Business intelligence tools

## Troubleshooting

### Common Issues

**1. Out of Memory Errors**
```bash
# Increase Java heap size
export ANT_OPTS="-Xmx16g -Xms4g"

# Monitor memory usage
free -h
top -p $(pgrep -f "moves")
```

**2. Database Connection Failures**
```bash
# Check MariaDB status
sudo systemctl status mariadb

# Test connection
mysql -u moves -pmoves -e "SELECT 1;"

# Check for locked tables
mysql -u moves -pmoves -e "SHOW OPEN TABLES WHERE In_use > 0;"
```

**3. Slow Performance**
```bash
# Check disk I/O
iostat -x 1

# Optimize temporary directory
export TMPDIR=/path/to/fast/storage
mkdir -p $TMPDIR
```

**4. Missing Output**
```bash
# Check for errors in logs
grep -i "error\|exception\|failed" *.log

# Verify output database
mysql -u moves -pmoves -e "SELECT COUNT(*) FROM movesoutput;" output_db
```

### Getting Help

For issues:
1. Check MOVES log files for specific errors
2. Review EPA's MOVES documentation
3. Consult the [Troubleshooting Guide](TROUBLESHOOTING.md)
4. Open an issue on GitHub with:
   - Runspec file (if possible)
   - Error messages from logs
   - System specifications

## Advanced Usage

### Custom Configurations

**Multiple Database Setups:**
```bash
# Configure different databases for different scenarios
mysql -u moves -pmoves -e "CREATE DATABASE moves_scenario1;"
mysql -u moves -pmoves -e "CREATE DATABASE moves_scenario2;"
```

**Automated Processing:**
```bash
#!/bin/bash
# Process multiple scenarios
for scenario in scenario1 scenario2 scenario3; do
    echo "Processing $scenario..."
    ant run -Drunspec="${scenario}.mrs"
    echo "Completed $scenario"
done
```

### Integration with Other Tools

MOVES can be integrated with:
- **SUMO** - Traffic simulation
- **CMAQ** - Air quality modeling  
- **R/Python** - Statistical analysis
- **GIS tools** - Spatial analysis

For detailed integration examples, see the EPA MOVES documentation and user community resources.