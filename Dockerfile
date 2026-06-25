# Build stage
ARG ECR_REPO
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /usr/src/app

# Copy only git related files first
COPY .gitmodules .
COPY .git ./.git

# Initialize and update submodules
RUN git submodule update --init --recursive

COPY . .
RUN mvn package -DskipTests

# Production stage
FROM tomcat:11.0.22-jdk21-temurin AS fnl_base_image

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip gosu \
    && apt-get install -y --no-install-recommends --only-upgrade \
    libcap2 libgnutls30t64 sed dpkg curl libcurl4t64 \
    locales libc-bin libc6 libssl3t64 openssl libpng16-16t64 \
    libnghttp2-14 libssh-4 libudev1 libsystemd0 libgcrypt20 \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/tomcat/webapps.dist \
    && rm -rf /usr/local/tomcat/webapps/ROOT \
    && groupadd -r tomcat && useradd -r -g tomcat -u 1000 tomcat \
    && mkdir -p /usr/local/tomcat/logs /usr/local/tomcat/work /usr/local/tomcat/temp \
    && chown -R tomcat:tomcat /usr/local/tomcat/logs /usr/local/tomcat/work /usr/local/tomcat/temp

# Modify the server.xml file to block error reporting
RUN sed -i 's|</Host>|  <Valve className="org.apache.catalina.valves.ErrorReportValve"\n               showReport="false"\n               showServerInfo="false" />\n\n      </Host>|' conf/server.xml

EXPOSE 8080
COPY --from=build /usr/src/app/target/Bento-0.0.1.war /usr/local/tomcat/webapps/ROOT.war
RUN mkdir /usr/local/tomcat/webapps/ROOT \
    && cd /usr/local/tomcat/webapps/ROOT \
    && jar -xf ../ROOT.war \
    && rm ../ROOT.war

COPY conf/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]