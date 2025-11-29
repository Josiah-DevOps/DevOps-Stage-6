# Multi-stage build for Go auth service
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Copy go mod files
COPY go.* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application (output as auth-api, not main)
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o auth-api .

# Production stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /root/

# Copy binary from builder
COPY --from=builder /app/auth-api .

EXPOSE 8080

CMD ["./auth-api"]
