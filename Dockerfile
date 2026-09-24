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
FROM tomcat:11.0.25-jdk21-temurin AS fnl_base_image

RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && apt-get install -y --no-install-recommends --only-upgrade \
    libcap2 libgnutls30t64 sed dpkg curl libcurl4t64 \
    locales libc-bin libc6 libssl3t64 openssl libpng16-16t64 \
    libnghttp2-14 libssh-4 libudev1 libsystemd0 libgcrypt20 \
    gzip tar perl-base wget libsqlite3-0 \
    liblzma5 ncurses-base libncursesw6 libtinfo6 ncurses-bin \
    libgssapi-krb5-2 libk5crypto3 libkrb5-3 libkrb5support0 \
    libpam-modules libpam-modules-bin libpam-runtime libpam0g \
    libexpat1 zlib1g libp11-kit0 p11-kit p11-kit-modules \
    libuuid1 libsmartcols1 libmount1 libblkid1 bsdutils util-linux \
    && (dpkg --compare-versions "$(dpkg-query -W -f='${Version}' openssl)" ge "3.0.13-0ubuntu3.15" || { echo "openssl version is below 3.0.13-0ubuntu3.15" >&2; exit 1; }) \
    && (dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libssl3t64)" ge "3.0.13-0ubuntu3.15" || { echo "libssl3t64 version is below 3.0.13-0ubuntu3.15" >&2; exit 1; }) \
    && (dpkg --compare-versions "$(dpkg-query -W -f='${Version}' perl-base)" ge "5.38.2-3.2ubuntu0.3" || { echo "perl-base version is below 5.38.2-3.2ubuntu0.3" >&2; exit 1; }) \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/local/tomcat/webapps.dist \
    && rm -rf /usr/local/tomcat/webapps/ROOT \
    && groupadd -r tomcat && useradd -r -g tomcat -u 1001 tomcat \
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

# Ensure writable dirs are owned by tomcat, then drop to non-root user
RUN chown -R tomcat:tomcat /usr/local/tomcat/webapps
USER tomcat
ENTRYPOINT ["catalina.sh", "run"]