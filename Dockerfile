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
FROM tomcat:11.0.29-jdk25-temurin-noble AS fnl_base_image

ENV JAVA_OPTS="-XX:InitialRAMPercentage=25 -XX:MaxRAMPercentage=70"
ENV TZ="America/New_York"
EXPOSE 8080

# Apply available updates to installed Ubuntu packages; verify and scan the image.
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

# Remove default applications and create the non-root Tomcat account.
RUN groupadd -r tomcat \
    && useradd -r -g tomcat -u 1001 tomcat \
    && rm -rf /usr/local/tomcat/webapps.dist \
    && rm -rf /usr/local/tomcat/webapps/ROOT \
    && mkdir -p /usr/local/tomcat/logs /usr/local/tomcat/work /usr/local/tomcat/temp

# copy the war file
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war

# Expand the WAR during the image build so Tomcat does not need to create ROOT at startup.
RUN mkdir -p /usr/local/tomcat/webapps/ROOT \
    && cd /usr/local/tomcat/webapps/ROOT \
    && jar -xf ../ROOT.war \
    && rm ../ROOT.war \
    && rm -rf WEB-INF/lib-provided

# Ensure Tomcat can access the application and write temporary/work files as non-root.
RUN chown -R tomcat:tomcat \
    /usr/local/tomcat/webapps \
    /usr/local/tomcat/logs \
    /usr/local/tomcat/work \
    /usr/local/tomcat/temp

USER tomcat
ENTRYPOINT ["catalina.sh", "run"]