# OpenTelemetry with ClickHouse

This project demonstrates how to set up an OpenTelemetry pipeline with ClickHouse as the backend storage. It uses tracegen for trace generation. The tracegen sends the traces to the otel collector and the collector exports these traces to Clickhouse.

## Architecture

The system consists of the following components:

- **Trace Generator**: Simulates application traces using the OpenTelemetry tracegen tool
- **OpenTelemetry Collector**: Receives, processes, and exports traces
- **ClickHouse Database**: Stores traces for analysis and querying

## Use Cases

Primarily this can be used for quick POC demos and concepts before moving to a production-grade setup.

- **Trace Collection**: The OpenTelemetry Collector can be used to receive traces from multiple applications and export them to ClickHouse.

- **Application Intergration**: Products like qryn, grafana, tempo can be integrated into the docker-compose file to visualize the traces.

## Components

### 1. Trace Generator (tracegen)

A containerized service that generates synthetic OpenTelemetry traces. Configurable parameters include:
- Number of workers
- Traces per worker
- Generation rate
- Continuous or one-time generation

### 2. OpenTelemetry Collector

Configured to:
- Receive traces via OTLP/gRPC protocol
- Process traces using batch processing
- Export traces to ClickHouse and debug output

### 3. ClickHouse Database

A high-performance columnar database that stores the trace data in a format optimized for analytical queries.

## Getting Started

### Prerequisites

- Docker and Docker Compose
- Bash shell

### Setup and Running

1. Clone this repository:
   ```bash
   git clone git@github.com:lkendrickd/otel-clickhouse.git
   cd otel-clickhouse
   ```

2. Start the services:
   ```bash
   docker-compose up # or docker compose up
   ```

3. Check if traces are being recorded:
   ```bash
   ./check_traces.sh
   ```

### Configuration

The main configuration files are:

- **docker-compose.yaml**: Defines the services, networks, and volumes
- **otel-collector-config.yaml**: Configures the OpenTelemetry Collector
- **clickhouse-init.sql**: Initializes the ClickHouse database
- **wrapper.sh**: Controls the trace generator behavior

## Telemetrygen Configuration Guide

The OpenTelemetry trace generator (telemetrygen) has been configured with a wrapper script that provides greater flexibility in controlling trace generation. Here's how to configure it for your needs:

### Configuration Parameters

All parameters can be set as environment variables in your `docker-compose.yml` file:

#### OTLP Connection Settings

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `OTLP_ENDPOINT` | Destination endpoint for telemetry data | `otel-collector:4317` | `collector:4317` |
| `OTLP_INSECURE` | Whether to use insecure connection | `true` | `false` |
| `OTLP_HTTP` | Use HTTP protocol instead of gRPC | `false` | `true` |
| `SERVICE_NAME` | Service name for generated traces | `telemetrygen-service` | `frontend-app` |

#### Trace Generation Controls

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `WORKERS` | Number of parallel workers generating traces | `1` | `2` |
| `TRACES_PER_WORKER` | Number of traces each worker generates per run | `1` | `10` |
| `CHILD_SPANS` | Number of child spans for each trace | `1` | `5` |
| `RATE` | Traces per second per worker (decimal for slower) | `1` | `0.1` |
| `SPAN_DURATION` | Duration of generated spans | `100ms` | `50ms` |
| `STATUS_CODE` | Status code for spans (0=Unset, 1=Error, 2=Ok) | `0` | `2` |

#### Runtime Behavior

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `RUN_INTERVAL` | Seconds between trace generation runs | `60` | `10` |
| `RUN_COUNT` | Number of times to run (0=infinite) | `0` | `5` |
| `ENABLE_BATCH` | Whether to batch traces | `true` | `false` |

#### Randomization Features

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `RANDOMIZE_CHILD_SPANS` | Randomize number of child spans | `false` | `true` |
| `MIN_CHILD_SPANS` | Minimum spans when randomizing | `1` | `2` |
| `MAX_CHILD_SPANS` | Maximum spans when randomizing | `5` | `10` |
| `RANDOMIZE_SPAN_DURATION` | Randomize span duration | `false` | `true` |
| `MIN_SPAN_DURATION` | Minimum duration (ms) when randomizing | `10` | `5` |
| `MAX_SPAN_DURATION` | Maximum duration (ms) when randomizing | `200` | `500` |

#### Additional Options

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `CUSTOM_ATTRIBUTES` | Custom attributes for traces | `""` | `env=\"prod\",region=\"us-east\"` |

### Common Configuration Scenarios

#### Slowing Down Trace Generation

To reduce the load and frequency of traces:

```yaml
environment:
  - RATE=0.1             # One trace every 10 seconds per worker
  - RUN_INTERVAL=30      # Wait 30 seconds between runs
  - WORKERS=1            # Use just one worker
  - TRACES_PER_WORKER=1  # Generate only one trace per run
```

#### Creating More Complex Traces

For more realistic trace hierarchies:

```yaml
environment:
  - CHILD_SPANS=8        # Create 8 child spans per trace
  - RANDOMIZE_CHILD_SPANS=true  # Vary the number of spans
  - MIN_CHILD_SPANS=3    # At least 3 child spans
  - MAX_CHILD_SPANS=12   # Up to 12 child spans
```

#### High-Volume Testing

For stress testing or performance evaluation:

```yaml
environment:
  - WORKERS=10           # 10 parallel workers
  - TRACES_PER_WORKER=100 # 100 traces each
  - RATE=50              # 50 traces per second per worker
  - RUN_INTERVAL=5       # Run every 5 seconds
```

#### One-Time Batch Generation

To generate a specific number of traces then stop:

```yaml
environment:
  - WORKERS=5            # 5 parallel workers
  - TRACES_PER_WORKER=20 # 20 traces each (100 total)
  - RUN_COUNT=1          # Run once and exit
  - RUN_INTERVAL=0       # Don't wait between runs
```

### Understanding Trace Rates

The actual number of traces generated depends on multiple factors:

- `WORKERS` × `TRACES_PER_WORKER` = Total traces per run
- `RATE` limits how fast each worker generates traces
- A run happens every `RUN_INTERVAL` seconds
- Total spans = Total traces × (1 + `CHILD_SPANS`)

For example, with 2 workers, 5 traces each, and 3 child spans, you'll get 10 traces with 40 total spans (10 root spans + 30 child spans) per run.

## Monitoring

Run the included script to check the status of traces in ClickHouse:

```bash
./scripts/check_traces.sh
```

This will output:
- Tables in the `otel` database
- Sample data from each table
- Row counts for each table

## Troubleshooting

### Common Issues

1. **Collector fails to start**:
   - Check if ClickHouse is fully initialized before the collector tries to connect
   - Verify network connectivity between services

2. **No traces appearing in ClickHouse**:
   - Check if the collector is properly receiving traces (debug exporter logs)
   - Verify ClickHouse is accepting connections
   - Ensure the otel database exists

3. **Trace generator not sending traces**:
   - Verify the collector endpoint is correct
   - Check network connectivity

4. **Telemetrygen Configuration Issues**:
   - Verify environment variables are being passed correctly:
     ```bash
     docker-compose exec telemetrygen env | grep RUN_INTERVAL
     ```
   - Check logs for run information:
     ```bash
     docker-compose logs telemetrygen | grep "Executing trace"
     ```
   - If changing variables doesn't take effect, rebuild the container:
     ```bash
     docker-compose build --no-cache telemetrygen
     docker-compose up -d
     ```

## Customization

### Scaling Trace Generation

Modify the environment variables in `docker-compose.yaml` for the `tracegen` service:

```yaml
environment:
  - WORKERS=2           # Increase for more parallel generation
  - TRACES_PER_WORKER=50 # Increase for more traces per worker
  - RATE=10             # traces per second across all workers
```

### Changing ClickHouse Configuration

Custom ClickHouse configurations can be added through the docker-compose volumes.

## License

MIT License

## Contributing

If you have an interesting idea drop a discussion or a PR.