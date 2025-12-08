# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod .
COPY main.go .
COPY tracing.go .
COPY user.go .
RUN go mod tidy
RUN go build -o auth-api .

# Run stage
FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/auth-api .
EXPOSE 8080
CMD ["./auth-api"]
