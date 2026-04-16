FROM maven:3.9.11-amazoncorretto-25 AS builder
WORKDIR /app
COPY . .
RUN mvn package -DskipTests --no-transfer-progress
FROM amazoncorretto:25 AS runner
WORKDIR /app
RUN yum update -y && yum list available shadow-utils && yum install -y shadow-utils-2:4.9-12.amzn2023.0.4 curl-minimal-8.5.0-1.amzn2023.0.2.aarch64 && yum clean all && useradd --create-home --uid 1001 appuser
COPY --from=builder /app/target/*.jar app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 CMD [ "sh", "-c", "curl -fsS http://127.0.0.1:8080/api/admin/health >/dev/null" ]
ENTRYPOINT ["java", "-jar", "app.jar"]
