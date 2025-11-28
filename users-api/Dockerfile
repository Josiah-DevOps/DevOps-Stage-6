# Multi-stage build for Java Spring Boot
FROM maven:3.8-openjdk-11 AS builder

WORKDIR /app

# Copy pom.xml
COPY pom.xml .

# Download dependencies
RUN mvn dependency:go-offline

# Copy source code
COPY src ./src

# Build the application
RUN mvn package -DskipTests

# Production stage
FROM openjdk:11-jre-slim

WORKDIR /app

# Copy jar from builder
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8083

CMD ["java", "-jar", "app.jar"]
