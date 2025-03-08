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
   docker-compose up
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

## Monitoring

Run the included script to check the status of traces in ClickHouse:

```bash
./check_traces.sh
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

## Customization

### Scaling Trace Generation

Modify the environment variables in `docker-compose.yaml` for the `tracegen` service:

```yaml
environment:
  - WORKERS=2           # Increase for more parallel generation
  - TRACES_PER_WORKER=50 # Increase for more traces per worker
  - RATE=10             # Adjust the rate of generation
```

### Changing ClickHouse Configuration

Custom ClickHouse configurations can be added through the docker-compose volumes.

## License

MIT License

## Contributing

If you have an interesting idea drop a discussion or a PR.