# Two stages from one base image, so the JRE that extracts the layers is the one that runs them.
# `make build` fails if this JRE's major is not .java-version. Dependabot bumps the digest.
FROM eclipse-temurin:25-jre-noble@sha256:2ef7a81085e0502d7d4ff7e7c0257b6d4f46433f8ea6021180aa3c8a2b9ca3ec AS builder
WORKDIR /builder
COPY target/*.jar application.jar
# Spring Boot's layered layout: dependencies change rarely, application code often, so most pulls are small.
RUN java -Djarmode=tools -jar application.jar extract --layers --destination extracted

FROM eclipse-temurin:25-jre-noble@sha256:2ef7a81085e0502d7d4ff7e7c0257b6d4f46433f8ea6021180aa3c8a2b9ca3ec
RUN useradd --system --uid 10001 --no-create-home dibs
WORKDIR /application
COPY --from=builder /builder/extracted/dependencies/ ./
COPY --from=builder /builder/extracted/spring-boot-loader/ ./
COPY --from=builder /builder/extracted/snapshot-dependencies/ ./
COPY --from=builder /builder/extracted/application/ ./
USER dibs
EXPOSE 8080 8081
ENTRYPOINT ["java", "-jar", "application.jar"]
