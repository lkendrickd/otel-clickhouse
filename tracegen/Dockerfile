FROM golang:1.20-alpine

# Install git and networking tools
RUN apk add --no-cache git netcat-openbsd

# Create a wrapper script for tracegen that ensures connection to the collector
WORKDIR /app
COPY wrapper.sh /app/
RUN chmod +x /app/wrapper.sh

# Install the tracegen tool
RUN go install github.com/open-telemetry/opentelemetry-collector-contrib/tracegen@latest

# Add /go/bin to PATH
ENV PATH="/go/bin:$PATH"

# Run the wrapper script
ENTRYPOINT ["/app/wrapper.sh"]