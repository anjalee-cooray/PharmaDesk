# ---------------------------------------------------------------------------
# PharmaDesk Core Monolith — Multi-stage Dockerfile
# Java 21 + Spring Boot 3.2
# ---------------------------------------------------------------------------

# Stage 1 — build
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /app

# Cache Gradle dependency layer separately from source
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle
RUN ./gradlew dependencies --no-daemon

COPY src ./src
RUN ./gradlew bootJar --no-daemon -x test

# Stage 2 — runtime (JRE only, no compiler)
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S pharmadesk && adduser -S pharmadesk -G pharmadesk
USER pharmadesk

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", \
  "-XX:+UseZGC", \
  "-XX:+ZGenerational", \
  "-Dspring.threads.virtual.enabled=true", \
  "-jar", "app.jar"]
