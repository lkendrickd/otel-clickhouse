#!/bin/bash
set -e

##########################################################
# Wrapper script for trace generation
#
# This script generates traces using the telemetrygen tool
# and sends them to an OpenTelemetry collector.
#
# The script controls the rate of trace generation and
# can run in continuous mode, generating traces at a
# regular interval, or just once.
##########################################################

# ANSI color codes for pretty logging
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get configuration from environment variables with defaults
# Collector settings
OTLP_ENDPOINT=${OTLP_ENDPOINT:-"otel-collector:4317"}
OTLP_INSECURE=${OTLP_INSECURE:-"true"}
OTLP_HTTP=${OTLP_HTTP:-"false"}
SERVICE_NAME=${SERVICE_NAME:-"telemetrygen-service"}

# Trace generation parameters
WORKERS=${WORKERS:-1}            # Number of parallel trace-generating workers
TRACES_PER_WORKER=${TRACES_PER_WORKER:-1}  # Number of trace trees each worker generates
CHILD_SPANS=${CHILD_SPANS:-1}    # Number of child spans per trace
RATE=${RATE:-1}                  # Rate limiting: traces per second per worker
SPAN_DURATION=${SPAN_DURATION:-"100ms"}  # Duration of each generated span
STATUS_CODE=${STATUS_CODE:-"0"}  # Status code for spans (0=Unset, 1=Error, 2=Ok)

# Randomization options
RANDOMIZE_CHILD_SPANS=${RANDOMIZE_CHILD_SPANS:-"false"}  # Whether to randomize child span count
MIN_CHILD_SPANS=${MIN_CHILD_SPANS:-1}                    # Minimum spans when randomizing
MAX_CHILD_SPANS=${MAX_CHILD_SPANS:-5}                    # Maximum spans when randomizing

RANDOMIZE_SPAN_DURATION=${RANDOMIZE_SPAN_DURATION:-"false"}  # Whether to randomize span duration
MIN_SPAN_DURATION=${MIN_SPAN_DURATION:-10}   # Minimum duration in milliseconds
MAX_SPAN_DURATION=${MAX_SPAN_DURATION:-200}  # Maximum duration in milliseconds

# Runtime options
RUN_INTERVAL=${RUN_INTERVAL:-60}  # Seconds between runs
RUN_COUNT=${RUN_COUNT:-0}         # 0 = run forever, otherwise run this many times

# Additional options
ENABLE_BATCH=${ENABLE_BATCH:-"true"}  # Whether to batch traces
CUSTOM_ATTRIBUTES=${CUSTOM_ATTRIBUTES:-""}  # Custom attributes for traces

# Display configuration
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

# Display configuration at startup
log $YELLOW "Trace Generator Configuration:"
log $YELLOW "├── Endpoint: $OTLP_ENDPOINT"
log $YELLOW "├── Service Name: $SERVICE_NAME"
log $YELLOW "├── Workers: $WORKERS"
log $YELLOW "├── Traces per worker: $TRACES_PER_WORKER"
log $YELLOW "├── Child spans: $CHILD_SPANS"
log $YELLOW "├── Rate limit: $RATE traces/second/worker"
log $YELLOW "└── Mode: $([ "$RUN_COUNT" = "0" ] && echo "Continuous (every ${RUN_INTERVAL}s)" || echo "Limited (${RUN_COUNT} runs)")"

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