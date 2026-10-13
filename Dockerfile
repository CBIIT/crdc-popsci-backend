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
FROM tomcat:11.0.26-jdk25-temurin-noble AS fnl_base_image

ENV JAVA_OPTS="-XX:InitialRAMPercentage=25 -XX:MaxRAMPercentage=70"
ENV TZ="America/New_York"
EXPOSE 8080

# Base image patching
RUN apt update && apt upgrade -y

# Remove existing webapps and create the non-root Tomcat account.
RUN groupadd -r tomcat \
    && useradd -r -g tomcat -u 1001 tomcat \
    && rm -rf /usr/local/tomcat/webapps/*

# copy the war file
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war

# Ensure Tomcat can expand the WAR and write temporary/work files as non-root.
RUN chown -R tomcat:tomcat \
    /usr/local/tomcat/webapps \
    /usr/local/tomcat/logs \
    /usr/local/tomcat/work \
    /usr/local/tomcat/temp

USER tomcat
ENTRYPOINT ["catalina.sh", "run"]