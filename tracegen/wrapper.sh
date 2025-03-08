#!/bin/sh
set -e

# Configuration with defaults
# Collector settings
COLLECTOR_HOST=${COLLECTOR_HOST:-otel-collector}
COLLECTOR_PORT=${COLLECTOR_PORT:-4317}
COLLECTOR_ENDPOINT="http://$COLLECTOR_HOST:$COLLECTOR_PORT"

# Trace generation settings
WORKERS=${WORKERS:-2}              # Number of parallel trace-generating workers
TRACES_PER_WORKER=${TRACES_PER_WORKER:-5}  # Number of trace trees each worker generates
RATE=${RATE:-5}                   # Rate limiting: traces per second across all workers
CONTINUOUS=${CONTINUOUS:-true}     # Whether to run continuously or just once
INTERVAL=${INTERVAL:-60}           # Seconds between batches in continuous mode
MAX_WAIT=${MAX_WAIT:-120}          # Maximum seconds to wait for collector

# Display configuration
echo "Trace Generator Configuration:"
echo "├── Collector: $COLLECTOR_ENDPOINT"
echo "├── Workers: $WORKERS"
echo "├── Traces per worker: $TRACES_PER_WORKER"
echo "├── Rate limit: $RATE traces/second"
echo "└── Mode: $([ "$CONTINUOUS" = "true" ] && echo "Continuous (every ${INTERVAL}s)" || echo "One-time")"

# Wait for collector with timeout
echo "Waiting for collector to be ready..."
WAIT_COUNT=0

while ! nc -z $COLLECTOR_HOST $COLLECTOR_PORT; do
  WAIT_COUNT=$((WAIT_COUNT+1))
  
  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "Error: Collector not available after ${MAX_WAIT} seconds. Exiting."
    exit 1
  fi
  
  echo "Waiting for collector at $COLLECTOR_HOST:$COLLECTOR_PORT ($WAIT_COUNT/${MAX_WAIT}s)..."
  sleep 1
done

echo "Collector is ready! Starting trace generation..."

# Set up networking
export GRPC_DNS_RESOLVER=native
export OTEL_EXPORTER_OTLP_ENDPOINT=$COLLECTOR_ENDPOINT

# Function to generate traces
generate_traces() {
  echo "Generating batch of $((WORKERS * TRACES_PER_WORKER)) traces at $RATE/second..."
  
  # Execute tracegen with parameters
  tracegen --otlp-endpoint=$COLLECTOR_HOST:$COLLECTOR_PORT \
    --workers=$WORKERS \
    --traces=$TRACES_PER_WORKER \
    --rate=$RATE
    
  echo "Trace batch completed at $(date)"
}

# Run in either continuous or one-time mode
if [ "$CONTINUOUS" = "true" ]; then
  echo "Running in continuous mode, generating traces every $INTERVAL seconds..."
  
  while true; do
    generate_traces
    
    echo "Waiting $INTERVAL seconds before next batch..."
    sleep $INTERVAL
  done
else
  # Run once and exit
  generate_traces
  echo "One-time trace generation completed."
fi