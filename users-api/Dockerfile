# Use Eclipse Temurin (better maintained)
FROM eclipse-temurin:11-jdk AS builder

WORKDIR /app

COPY pom.xml .
RUN apt-get update && apt-get install -y maven
RUN mvn dependency:go-offline

COPY src ./src
RUN mvn package -DskipTests

FROM eclipse-temurin:11-jre
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8083
CMD ["java", "-jar", "app.jar"]
