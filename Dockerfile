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

# POPSCI-595: install the required package and upgrade only the Ubuntu packages
# pinned here to remediate the in-scope perl-base and p11-kit container CVEs.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        unzip \
        perl-base=5.38.2-3.2ubuntu0.4 \
        p11-kit=0.25.3-4ubuntu2.2 \
        libp11-kit0=0.25.3-4ubuntu2.2 \
        p11-kit-modules=0.25.3-4ubuntu2.2 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN rm -rf /usr/local/tomcat/webapps.dist
RUN rm -rf /usr/local/tomcat/webapps/ROOT.war

# Modify the server.xml file to block error reportiing
RUN sed -i 's|</Host>|  <Valve className="org.apache.catalina.valves.ErrorReportValve"\n               showReport="false"\n               showServerInfo="false" />\n\n      </Host>|' conf/server.xml 

# expose ports
EXPOSE 8080
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war
