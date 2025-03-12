#!/bin/bash
# Author: Converted from original script
# Description: Wrapper script for trace generation using the telemetrygen tool
#              and sends them to an OpenTelemetry collector.
#              
#
# Primary Use Case: Generates traces at a controlled rate and can run in continuous mode
#                   or for a limited number of iterations.
#
# Execution:
# 
# ./trace-generator.sh --service-name my-service --endpoint otel-collector:4317
# 
# Prereqs: telemetrygen tool must be installed
#
#-------------------------------------------------------------------
# OPERATIONS - tasks that the script executes
#   - Checks prerequisites
#   - Configures trace generation parameters
#   - Generates traces using telemetrygen 
#   - Can run continuously or for a specified number of iterations
#-------------------------------------------------------------------
# Global Vars
#-------------------------------------------------------------------
scriptname=$(basename $0)

# Required binaries for the script to execute
REQUIRED_BINARIES="which telemetrygen sleep"

# ANSI color codes for pretty logging
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default verbose logging on 
VERBOSE=1

# Collector settings with defaults
OTLP_ENDPOINT="otel-collector:4317"
OTLP_INSECURE="true"
OTLP_HTTP="false"
SERVICE_NAME="telemetrygen-service"

# Trace generation parameters with defaults
WORKERS=1            # Number of parallel trace-generating workers
TRACES_PER_WORKER=1  # Number of trace trees each worker generates
CHILD_SPANS=1        # Number of child spans per trace
RATE=1               # Rate limiting: traces per second per worker
SPAN_DURATION="100ms"  # Duration of each generated span
STATUS_CODE="0"      # Status code for spans (0=Unset, 1=Error, 2=Ok)

# Randomization options
RANDOMIZE_CHILD_SPANS="false"  # Whether to randomize child span count
MIN_CHILD_SPANS=1              # Minimum spans when randomizing
MAX_CHILD_SPANS=5              # Maximum spans when randomizing

RANDOMIZE_SPAN_DURATION="false"  # Whether to randomize span duration
MIN_SPAN_DURATION=10   # Minimum duration in milliseconds
MAX_SPAN_DURATION=200  # Maximum duration in milliseconds

# Runtime options
RUN_INTERVAL=60  # Seconds between runs
RUN_COUNT=0      # 0 = run forever, otherwise run this many times

# Additional options
ENABLE_BATCH="true"  # Whether to batch traces
CUSTOM_ATTRIBUTES=""  # Custom attributes for traces

#########################################################################
# Functions
#########################################################################

# execute - runs the main trace generation process
execute() {
    verbose "Starting trace generation process"
    
    # Display configuration at startup
    log $YELLOW "Trace Generator Configuration:"
    log $YELLOW "├── Endpoint: $OTLP_ENDPOINT"
    log $YELLOW "├── Service Name: $SERVICE_NAME"
    log $YELLOW "├── Workers: $WORKERS"
    log $YELLOW "├── Traces per worker: $TRACES_PER_WORKER"
    log $YELLOW "├── Child spans: $CHILD_SPANS"
    log $YELLOW "├── Rate limit: $RATE traces/second/worker"
    if [ "$RUN_COUNT" = "0" ]; then
        run_mode="Continuous (every ${RUN_INTERVAL}s)"
    else
        run_mode="Limited (${RUN_COUNT} runs)"
    fi
    log $YELLOW "└── Mode: $run_mode"
    
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
        
        generate_traces $count
        
        # If we're not running forever, exit after one iteration
        if [ "$RUN_INTERVAL" -eq 0 ]; then
            log $YELLOW "Run interval set to 0. Exiting after one run."
            exit 0
        fi
        
        # Wait before the next iteration
        log $BLUE "Waiting $RUN_INTERVAL seconds before next run..."
        sleep $RUN_INTERVAL
    done
}

# generate_traces - generates a batch of traces
generate_traces() {
    local run_number=$1
    
    # Apply randomization if configured
    if [ "$RANDOMIZE_CHILD_SPANS" = "true" ]; then
        CHILD_SPANS=$(random_int $MIN_CHILD_SPANS $MAX_CHILD_SPANS)
        log $BLUE "Randomized child spans: $CHILD_SPANS"
    fi
    
    if [ "$RANDOMIZE_SPAN_DURATION" = "true" ]; then
        rand_duration=$(random_int $MIN_SPAN_DURATION $MAX_SPAN_DURATION)
        SPAN_DURATION="${rand_duration}ms"
        log $BLUE "Randomized span duration: $SPAN_DURATION"
    fi
    
    # Build the command
    CMD="telemetrygen traces"
    CMD+=" --otlp-endpoint $OTLP_ENDPOINT"
    
    # Add optional flags
    [ "$OTLP_INSECURE" = "true" ] && CMD+=" --otlp-insecure"
    [ "$OTLP_HTTP" = "true" ] && CMD+=" --otlp-http"
    [ "$ENABLE_BATCH" = "true" ] && CMD+=" --batch"
    
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
        IFS=','
        for attr in $CUSTOM_ATTRIBUTES; do
            CMD+=" --otlp-attributes $attr"
        done
        unset IFS
    fi
    
    # Log and execute the command
    log $YELLOW "Run #$run_number: Executing trace generation command"
    log $BLUE "$CMD"
    
    # Execute the command
    eval $CMD
    
    result=$?
    if [ $result -eq 0 ]; then
        log $GREEN "✓ Trace generation completed successfully"
    else
        log $RED "✗ Trace generation failed with exit code: $result"
    fi
}

# Function to generate a random integer between min and max (inclusive)
random_int() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

# log - helper function for colored logging
log() {
    local color=$1
    local message=$2
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')] $message${NC}"
}

#########################################################################
# UTILITY FUNCTIONS SECTION - functions that perform a utility tasks
#########################################################################

# check_prerequsites - checks for any prerequsites packages or binaries that need installed
check_prerequisites() {
    missing_counter=0
    verbose "Checking for prerequisites..."

    for bin in $REQUIRED_BINARIES; do
        if ! command -v "$bin" > /dev/null 2>&1; then
            echo "Missing required binary: $bin"
            missing_counter=$((missing_counter + 1))
        fi
    done

    if [ "$missing_counter" -ne 0 ]; then
        echo "Error: $missing_counter required binaries are missing."
        exit 1
    fi

    verbose "All prerequisites are met."
}

# check_root - checks if the script is being run as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        errexit "This script must be run as root"
    fi
}

# errexit - message and exit the script
errexit() {
    # Function for exit due to fatal program error
    # Accepts 1 arg: string containing descriptive error message
    echo "${scriptname}: ${1:-"Unknown Error"}" >&2
    exit 1
}

# load_config - loads the config file if it exists
load_config() {
    if [ -f ${CONFIG} ]; then
        . ${CONFIG}
        verbose "Config file loaded"
    else
        errexit "Config file not found"
    fi
}

# printenv - prints all environment variables usually for debugging
printenv() {
    env | sort
}

# signal_exit - handles signals sent to the script
signal_exit() {
    case ${1} in
        INT)
            echo "${scriptname}: Program aborted by user" >&2
            exit;;
        TERM)
            echo "${scriptname}: Program terminated" >&2
            exit;;
        HUP)
            echo "${scriptname}: Hangup signal received" >&2
            ;;
        QUIT)
            echo "${scriptname}: Quit signal received" >&2
            exit;;
        ABRT)
            echo "${scriptname}: Abort signal received" >&2
            exit;;
        KILL)
            echo "${scriptname}: Kill signal received" >&2
            exit;;
        ALRM)
            echo "${scriptname}: Alarm signal received" >&2
            ;;
        *)
            errexit "${scriptname}: Terminating on unknown signal";;
    esac
}

# trap signals
trap 'signal_exit INT' INT
trap 'signal_exit TERM' TERM
trap 'signal_exit HUP' HUP
trap 'signal_exit QUIT' QUIT
trap 'signal_exit ABRT' ABRT
trap 'signal_exit KILL' KILL
trap 'signal_exit ALRM' ALRM

# usage - displays the usage of the script it uses the comments in the while loop below
# to construct a usage message
usage() {
    echo "Usage: $scriptname [OPTIONS]"
    echo
    echo "Options:"
    grep '# HELP:' "$0" | grep -v 'grep' | sed 's/# HELP: //'
    echo
    echo "Example: ./$scriptname --service-name my-service --endpoint otel-collector:4317"
}

# verbose - prints a verbose message
verbose() {
    if [ ${VERBOSE} -eq 1 ]; then
        echo "[INFO]: ${1}"
    fi
}

######################################################################
#  Start Script Execution
######################################################################

# Trap various signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT
trap "signal_exit QUIT" QUIT
trap "signal_exit ABRT" ABRT
trap "signal_exit KILL" KILL
trap "signal_exit ALRM" ALRM

# This loop will parse the command line arguments
while [ "$#" -gt 0 ]; do
    case "$1" in
        # HELP: -h, --help: Displays the usage of the script
        -h|--help)
            usage
            exit 0
            ;;
        # HELP: -c, --config: Path to a config file to load
        -c|--config)
            CONFIG="$2"
            shift 2
            ;;
        # HELP: -e, --endpoint: OTLP endpoint (default: otel-collector:4317)
        -e|--endpoint)
            OTLP_ENDPOINT="$2"
            shift 2
            ;;
        # HELP: -s, --service-name: Service name for generated traces (default: telemetrygen-service)
        -s|--service-name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        # HELP: -w, --workers: Number of parallel workers generating traces (default: 1)
        -w|--workers)
            WORKERS="$2"
            shift 2
            ;;
        # HELP: -t, --traces: Number of traces per worker (default: 1)
        -t|--traces)
            TRACES_PER_WORKER="$2"
            shift 2
            ;;
        # HELP: -cs, --child-spans: Number of child spans per trace (default: 1)
        -cs|--child-spans)
            CHILD_SPANS="$2"
            shift 2
            ;;
        # HELP: -r, --rate: Rate limit in traces per second per worker (default: 1)
        -r|--rate)
            RATE="$2"
            shift 2
            ;;
        # HELP: -d, --duration: Span duration (default: 100ms)
        -d|--duration)
            SPAN_DURATION="$2"
            shift 2
            ;;
        # HELP: --status-code: Status code for spans (0=Unset, 1=Error, 2=Ok) (default: 0)
        --status-code)
            STATUS_CODE="$2"
            shift 2
            ;;
        # HELP: --interval: Seconds between runs (default: 60, 0 = run once)
        --interval)
            RUN_INTERVAL="$2"
            shift 2
            ;;
        # HELP: --count: Number of runs (default: 0 = run forever)
        --count)
            RUN_COUNT="$2"
            shift 2
            ;;
        # HELP: --insecure: Use insecure connection (default: true)
        --insecure)
            OTLP_INSECURE="$2"
            shift 2
            ;;
        # HELP: --http: Use HTTP instead of gRPC (default: false)
        --http)
            OTLP_HTTP="$2"
            shift 2
            ;;
        # HELP: --batch: Enable batching of traces (default: true)
        --batch)
            ENABLE_BATCH="$2"
            shift 2
            ;;
        # HELP: --attributes: Custom attributes as comma-separated key=value pairs
        --attributes)
            CUSTOM_ATTRIBUTES="$2"
            shift 2
            ;;
        # HELP: --randomize-spans: Enable randomization of child spans (default: false)
        --randomize-spans)
            RANDOMIZE_CHILD_SPANS="$2"
            shift 2
            ;;
        # HELP: --min-spans: Minimum spans when randomizing (default: 1)
        --min-spans)
            MIN_CHILD_SPANS="$2"
            shift 2
            ;;
        # HELP: --max-spans: Maximum spans when randomizing (default: 5)
        --max-spans)
            MAX_CHILD_SPANS="$2"
            shift 2
            ;;
        # HELP: --randomize-duration: Enable randomization of span duration (default: false)
        --randomize-duration)
            RANDOMIZE_SPAN_DURATION="$2"
            shift 2
            ;;
        # HELP: --min-duration: Minimum duration in ms when randomizing (default: 10)
        --min-duration)
            MIN_SPAN_DURATION="$2"
            shift 2
            ;;
        # HELP: --max-duration: Maximum duration in ms when randomizing (default: 200)
        --max-duration)
            MAX_SPAN_DURATION="$2"
            shift 2
            ;;
        # HELP: -v, --verbose: Enable verbose output (default: true)
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        # HELP: -q, --quiet: Disable verbose output
        -q|--quiet)
            VERBOSE=0
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check environment variables for any config that wasn't set by command-line
# This allows for backward compatibility with the original script's env var configuration
[ -n "$OTLP_ENDPOINT" ] || OTLP_ENDPOINT=${OTLP_ENDPOINT:-"otel-collector:4317"}
[ -n "$OTLP_INSECURE" ] || OTLP_INSECURE=${OTLP_INSECURE:-"true"}
[ -n "$OTLP_HTTP" ] || OTLP_HTTP=${OTLP_HTTP:-"false"}
[ -n "$SERVICE_NAME" ] || SERVICE_NAME=${SERVICE_NAME:-"telemetrygen-service"}
[ -n "$WORKERS" ] || WORKERS=${WORKERS:-1}
[ -n "$TRACES_PER_WORKER" ] || TRACES_PER_WORKER=${TRACES_PER_WORKER:-1}
[ -n "$CHILD_SPANS" ] || CHILD_SPANS=${CHILD_SPANS:-1}
[ -n "$RATE" ] || RATE=${RATE:-1}
[ -n "$SPAN_DURATION" ] || SPAN_DURATION=${SPAN_DURATION:-"100ms"}
[ -n "$STATUS_CODE" ] || STATUS_CODE=${STATUS_CODE:-"0"}
[ -n "$RANDOMIZE_CHILD_SPANS" ] || RANDOMIZE_CHILD_SPANS=${RANDOMIZE_CHILD_SPANS:-"false"}
[ -n "$MIN_CHILD_SPANS" ] || MIN_CHILD_SPANS=${MIN_CHILD_SPANS:-1}
[ -n "$MAX_CHILD_SPANS" ] || MAX_CHILD_SPANS=${MAX_CHILD_SPANS:-5}
[ -n "$RANDOMIZE_SPAN_DURATION" ] || RANDOMIZE_SPAN_DURATION=${RANDOMIZE_SPAN_DURATION:-"false"}
[ -n "$MIN_SPAN_DURATION" ] || MIN_SPAN_DURATION=${MIN_SPAN_DURATION:-10}
[ -n "$MAX_SPAN_DURATION" ] || MAX_SPAN_DURATION=${MAX_SPAN_DURATION:-200}
[ -n "$RUN_INTERVAL" ] || RUN_INTERVAL=${RUN_INTERVAL:-60}
[ -n "$RUN_COUNT" ] || RUN_COUNT=${RUN_COUNT:-0}
[ -n "$ENABLE_BATCH" ] || ENABLE_BATCH=${ENABLE_BATCH:-"true"}
[ -n "$CUSTOM_ATTRIBUTES" ] || CUSTOM_ATTRIBUTES=${CUSTOM_ATTRIBUTES:-""}

# check for required prereqs
check_prerequisites

# check is CONFIG was passed in and set
if [ -n "${CONFIG+x}" ]; then
    load_config
else
    verbose "No config file specified, using defaults and command-line options"
fi

# Uncomment below to debug the script environment variables
#printenv

execute
verbose "Process completed successfully."
exit 0