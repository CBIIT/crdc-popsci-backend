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

# Upgrade CVE-affected packages and install required tools, then clean up
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        openssl \
        libssl3t64 \
        perl-base \
        unzip && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' openssl)" ge "3.0.13-0ubuntu3.15" || { echo "openssl version is below 3.0.13-0ubuntu3.15" >&2; exit 1; } && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libssl3t64)" ge "3.0.13-0ubuntu3.15" || { echo "libssl3t64 version is below 3.0.13-0ubuntu3.15" >&2; exit 1; } && \
    dpkg --compare-versions "$(dpkg-query -W -f='${Version}' perl-base)" ge "5.38.2-3.2ubuntu0.3" || { echo "perl-base version is below 5.38.2-3.2ubuntu0.3" >&2; exit 1; } && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN rm -rf /usr/local/tomcat/webapps.dist
RUN rm -rf /usr/local/tomcat/webapps/ROOT.war

# Modify the server.xml file to block error reportiing
RUN sed -i 's|</Host>|  <Valve className="org.apache.catalina.valves.ErrorReportValve"\n               showReport="false"\n               showServerInfo="false" />\n\n      </Host>|' conf/server.xml 

# expose ports
EXPOSE 8080
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war
