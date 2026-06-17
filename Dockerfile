# Build stage
ARG ECR_REPO
FROM maven:3.8.5-openjdk-17 as build
WORKDIR /usr/src/app

# Copy only git related files first
COPY .gitmodules .
COPY .git ./.git

# Initialize and update submodules
RUN git submodule update --init --recursive

COPY . .
RUN mvn package -DskipTests

# Production stage
#FROM tomcat:11.0.10-jdk17-temurin-noble AS fnl_base_image
FROM tomcat:11.0.18-jdk17-temurin-noble AS fnl_base_image

# Update and install required packages, then clean up.
# apt-get upgrade installs available security patches for base-image packages,
# including fixes for CVEs addressed in POPSCI-531 (curl, dpkg, libcap2,
# libgcrypt20, libgnutls30t64, and others where upstream patches are available).
# Last updated: 2026-06-17
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y unzip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN rm -rf /usr/local/tomcat/webapps.dist
RUN rm -rf /usr/local/tomcat/webapps/ROOT.war

# Modify the server.xml file to block error reportiing
RUN sed -i 's|</Host>|  <Valve className="org.apache.catalina.valves.ErrorReportValve"\n               showReport="false"\n               showServerInfo="false" />\n\n      </Host>|' conf/server.xml 

# expose ports
EXPOSE 8080
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war
