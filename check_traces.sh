#!/bin/bash

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Config
CONTAINER_NAME="otel-clickhouse-clickhouse-1"
DB_PASSWORD="password"
DATABASE="otel"

# Title banner
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       OpenTelemetry ClickHouse Report      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

# Function to execute ClickHouse queries
clickhouse_query() {
  docker exec ${CONTAINER_NAME} clickhouse-client --password=${DB_PASSWORD} -q "$1"
}

# Check if ClickHouse is running
echo -e "\n${YELLOW}[1/3]${NC} Checking ClickHouse service status..."
if ! docker ps | grep -q ${CONTAINER_NAME}; then
  echo -e "${RED}✘ ClickHouse container is not running!${NC}"
  exit 1
else
  echo -e "${GREEN}✓ ClickHouse container is running${NC}"
fi

# Check if the database exists
echo -e "\n${YELLOW}[2/3]${NC} Checking database status..."
if ! clickhouse_query "SHOW DATABASES LIKE '${DATABASE}'" | grep -q "${DATABASE}"; then
  echo -e "${YELLOW}⚠ The ${DATABASE} database does not exist yet${NC}"
  echo -e "${YELLOW}  Creating ${DATABASE} database...${NC}"
  clickhouse_query "CREATE DATABASE IF NOT EXISTS ${DATABASE}"
  echo -e "${GREEN}✓ Database created successfully${NC}"
else
  echo -e "${GREEN}✓ The ${DATABASE} database exists${NC}"
fi

# Get a list of tables in the otel database
echo -e "\n${YELLOW}[3/3]${NC} Analyzing tables in ${DATABASE} database..."
TABLES=$(clickhouse_query "SHOW TABLES FROM ${DATABASE}")

if [ -z "$TABLES" ]; then
  echo -e "${YELLOW}⚠ No tables found in the ${DATABASE} database${NC}"
  echo -e "${YELLOW}  Make sure your collector is properly configured and running${NC}"
else
  # Count tables
  TABLE_COUNT=$(echo "$TABLES" | wc -l)
  echo -e "${GREEN}✓ Found ${TABLE_COUNT} tables in the ${DATABASE} database${NC}\n"
  
  echo -e "${BLUE}┌─ Table Details ───────────────────────────┐${NC}"
  
  # For each table, show row count and sample data
  echo "$TABLES" | while read -r TABLE; do
    if [ -n "$TABLE" ]; then
      # Get row count
      COUNT=$(clickhouse_query "SELECT count() FROM ${DATABASE}.\`${TABLE}\`")
      
      echo -e "${BLUE}│${NC} ${GREEN}Table:${NC} ${TABLE}"
      echo -e "${BLUE}│${NC} ${GREEN}Row count:${NC} ${COUNT}"
      
      if [ "$COUNT" -gt 0 ]; then
        echo -e "${BLUE}│${NC} ${GREEN}Sample data:${NC}"
        echo -e "${BLUE}│${NC}"
        clickhouse_query "SELECT * FROM ${DATABASE}.\`${TABLE}\` LIMIT 3 FORMAT Pretty" | sed "s/^/${BLUE}│${NC} /"
        echo -e "${BLUE}│${NC}"
      else
        echo -e "${BLUE}│${NC} ${YELLOW}No data available in this table yet${NC}"
        echo -e "${BLUE}│${NC}"
      fi
      
      echo -e "${BLUE}├───────────────────────────────────────────┤${NC}"
    fi
  done
  
  echo -e "${BLUE}└───────────────────────────────────────────┘${NC}"
fi

echo -e "\n${GREEN}ClickHouse trace analysis complete!${NC}"
echo -e "${YELLOW}Run this script periodically to monitor your trace data${NC}"
