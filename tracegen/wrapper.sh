#!/bin/bash
set -e

# ANSI color codes for pretty logging
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get configuration from environment variables with defaults
OTLP_ENDPOINT=${OTLP_ENDPOINT:-"otel-collector:4317"}
OTLP_INSECURE=${OTLP_INSECURE:-"true"}
OTLP_HTTP=${OTLP_HTTP:-"false"}
SERVICE_NAME=${SERVICE_NAME:-"telemetrygen-service"}

# Trace generation parameters
WORKERS=${WORKERS:-1}
TRACES_PER_WORKER=${TRACES_PER_WORKER:-1}
CHILD_SPANS=${CHILD_SPANS:-1}
RATE=${RATE:-1}
SPAN_DURATION=${SPAN_DURATION:-"100ms"}
STATUS_CODE=${STATUS_CODE:-"0"}

# Randomization options
RANDOMIZE_CHILD_SPANS=${RANDOMIZE_CHILD_SPANS:-"false"}
MIN_CHILD_SPANS=${MIN_CHILD_SPANS:-1}
MAX_CHILD_SPANS=${MAX_CHILD_SPANS:-5}

RANDOMIZE_SPAN_DURATION=${RANDOMIZE_SPAN_DURATION:-"false"}
MIN_SPAN_DURATION=${MIN_SPAN_DURATION:-10}  # in milliseconds
MAX_SPAN_DURATION=${MAX_SPAN_DURATION:-200} # in milliseconds

# Runtime options
RUN_INTERVAL=${RUN_INTERVAL:-60}  # seconds between runs
RUN_COUNT=${RUN_COUNT:-0}         # 0 = run forever, otherwise run this many times

# Additional options
ENABLE_BATCH=${ENABLE_BATCH:-"true"}
CUSTOM_ATTRIBUTES=${CUSTOM_ATTRIBUTES:-""}

# Function to log with timestamp and color
log() {
  local color=$1
  local message=$2
  echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}"
}

# Function to generate a random integer between min and max (inclusive)
random_int() {
  local min=$1
  local max=$2
  echo $((RANDOM % (max - min + 1) + min))
}

# Count how many runs we've done
count=0

# Main loop
while true; do
  # Increment run counter
  count=$((count + 1))
  
  # Check if we've reached the run limit (if not 0)
  if [ "$RUN_COUNT" -gt 0 ] && [ "$count" -gt "$RUN_COUNT" ]; then
    log $GREEN "Completed $RUN_COUNT runs. Exiting."
    exit 0
  fi
  
  # Apply randomization if configured
  if [ "$RANDOMIZE_CHILD_SPANS" == "true" ]; then
    CHILD_SPANS=$(random_int $MIN_CHILD_SPANS $MAX_CHILD_SPANS)
    log $BLUE "Randomized child spans: $CHILD_SPANS"
  fi
  
  if [ "$RANDOMIZE_SPAN_DURATION" == "true" ]; then
    rand_duration=$(random_int $MIN_SPAN_DURATION $MAX_SPAN_DURATION)
    SPAN_DURATION="${rand_duration}ms"
    log $BLUE "Randomized span duration: $SPAN_DURATION"
  fi
  
  # Build the command
  CMD="telemetrygen traces"
  CMD+=" --otlp-endpoint $OTLP_ENDPOINT"
  
  # Add optional flags
  [ "$OTLP_INSECURE" == "true" ] && CMD+=" --otlp-insecure"
  [ "$OTLP_HTTP" == "true" ] && CMD+=" --otlp-http"
  [ "$ENABLE_BATCH" == "true" ] && CMD+=" --batch"
  
  # Add required parameters
  CMD+=" --workers $WORKERS"
  CMD+=" --traces $TRACES_PER_WORKER"
  CMD+=" --child-spans $CHILD_SPANS"
  CMD+=" --rate $RATE"
  CMD+=" --span-duration $SPAN_DURATION"
  CMD+=" --status-code $STATUS_CODE"
  CMD+=" --service $SERVICE_NAME"
  
  # Add custom attributes if defined
  if [ -n "$CUSTOM_ATTRIBUTES" ]; then
    # Split the string on commas and process each key=value pair
    IFS=',' read -ra ATTR_ARRAY <<< "$CUSTOM_ATTRIBUTES"
    for attr in "${ATTR_ARRAY[@]}"; do
      CMD+=" --otlp-attributes $attr"
    done
  fi
  
  # Log and execute the command
  log $YELLOW "Run #$count: Executing trace generation command"
  log $BLUE "$CMD"
  
  # Execute the command
  eval $CMD
  
  result=$?
  if [ $result -eq 0 ]; then
    log $GREEN "✓ Trace generation completed successfully"
  else
    log $RED "✗ Trace generation failed with exit code: $result"
  fi
  
  # If we're not running forever, exit after one iteration
  if [ "$RUN_INTERVAL" -eq 0 ]; then
    log $YELLOW "Run interval set to 0. Exiting after one run."
    exit 0
  fi
  
  # Wait before the next iteration
  log $BLUE "Waiting $RUN_INTERVAL seconds before next run..."
  sleep $RUN_INTERVAL
done