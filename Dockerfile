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

# Update and install required packages, then clean up
# Remediates POPSCI-536 base-image CVEs:
#   CVE-2026-8925:           curl, libcurl4t64   fixed in 8.5.0-2ubuntu10.10
#   CVE-2026-41991/41992:    gzip                fixed in 1.12-1ubuntu3.2
#   CVE-2026-11822/11824:    libsqlite3-0        fixed in 3.45.1-1ubuntu2.6
#   CVE-2026-13757:          libp11-kit0, p11-kit, p11-kit-modules — no fix available in Ubuntu yet
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --only-upgrade \
        curl \
        libcurl4t64 \
        gzip \
        libsqlite3-0 && \
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
