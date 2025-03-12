# Stage 1: Build the telemetrygen binary
FROM golang:1.23-alpine AS builder

# Install git for fetching dependencies
RUN apk add --no-cache git

# Download and compile telemetrygen
RUN go install github.com/open-telemetry/opentelemetry-collector-contrib/cmd/telemetrygen@latest

# Stage 2: Create the final image
FROM alpine:3.19

# Install bash and utilities
RUN apk add --no-cache bash jq curl

# Copy the binary from the builder stage
COPY --from=builder /go/bin/telemetrygen /usr/local/bin/telemetrygen

# Copy wrapper script
COPY wrapper.sh /app/wrapper.sh
RUN chmod +x /app/wrapper.sh

# Set working directory
WORKDIR /app

# ========================================================
# Default environment variables with detailed explanations
# ========================================================

# OTLP Connection Configuration
# ----------------------------
# Destination for sending telemetry data (host:port)
ENV OTLP_ENDPOINT="otel-collector:4317"
# Whether to use insecure connection (true/false)
ENV OTLP_INSECURE="true"
# Whether to use HTTP instead of gRPC (true/false)
ENV OTLP_HTTP="false"
# Service name to use for generated telemetry
ENV SERVICE_NAME="telemetrygen-service"

# Trace Generation Parameters
# --------------------------
# Number of parallel workers (goroutines) generating traces
ENV WORKERS="1"
# Number of traces for each worker to generate
ENV TRACES_PER_WORKER="1"
# Number of child spans to create for each trace
ENV CHILD_SPANS="1"
# How many traces per second to generate (per worker)
ENV RATE="1"
# Duration of each generated span
ENV SPAN_DURATION="100ms"
# Status code to use (0=Unset, 1=Error, 2=Ok)
ENV STATUS_CODE="0"

# Randomization Options
# --------------------
# Whether to randomize child span count (true/false)
ENV RANDOMIZE_CHILD_SPANS="true"
# Minimum child spans when randomizing
ENV MIN_CHILD_SPANS="1"
# Maximum child spans when randomizing
ENV MAX_CHILD_SPANS="5"
# Whether to randomize span duration (true/false)
ENV RANDOMIZE_SPAN_DURATION="false"
# Minimum span duration in ms when randomizing
ENV MIN_SPAN_DURATION="10"
# Maximum span duration in ms when randomizing
ENV MAX_SPAN_DURATION="200"

# Runtime Control
# --------------
# Time in seconds between trace generation runs
# Set to 0 to run once and exit
ENV RUN_INTERVAL="30"
# How many times to run the generator
# 0 = run forever, N = run N times then exit
ENV RUN_COUNT="0"

# Additional Options
# ----------------
# Whether to enable trace batching (true/false)
ENV ENABLE_BATCH="true"
# Custom attributes to add to traces in format:
# "key1=\"value1\",key2=\"value2\",key3=true"
ENV CUSTOM_ATTRIBUTES=""

# Run wrapper script by default
ENTRYPOINT ["/app/wrapper.sh"]