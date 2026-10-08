# Build stage
FROM maven:3.9.16-eclipse-temurin-25-noble AS build
WORKDIR /usr/src/app

# download dependencies
COPY pom.xml .
RUN mvn -B dependency:go-offline dependency:resolve-plugins -DskipTests

# copy source code and build the project
COPY src ./src
RUN mvn -B package -DskipTests

# Production stage
FROM tomcat:11.0.26-jdk25-temurin-noble@sha256:b3106f307e52ec60ba67e1ad5daa7d6ad6259f5321ccec565d3f0985b287dd5d AS fnl_base_image

ENV JAVA_OPTS="-XX:InitialRAMPercentage=25 -XX:MaxRAMPercentage=70"
ENV TZ="America/New_York"
EXPOSE 8080
# remove existing webapps (including examples), copy the new war file, and run as non-root
RUN useradd -r nonrootuser && rm -rf /usr/local/tomcat/webapps/*
# copy the war file
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war
# change ownership of the tomcat directory to the nonroot user
RUN chown -R nonrootuser:nonrootuser /usr/local/tomcat
# Base image patching
RUN apt update && apt upgrade -y
# switch to nonroot user
USER nonrootuser