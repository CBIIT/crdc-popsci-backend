# Population Science Data Commons(PSDC) Backend

The CRDC PSDC backend is a Spring Boot API packaged as a WAR for external Tomcat. It serves private and public GraphQL queries backed by OpenSearch. Shared Bento application code lives in the `bento-backend-core` Git submodule at `src/main/java/gov/nih/nci/bento`.

## Prerequisites

- Eclipse Temurin JDK 25. The repository includes the Maven wrapper, so a separate Maven installation is not required.
- Access to the Neo4j and OpenSearch services configured for the target environment. Redis and request authentication are optional and controlled by configuration.
- Docker to build the production WAR image on Tomcat 11 / JDK 25.

## Setup

Initialize the shared backend submodule after cloning:

```sh
git submodule update --init --recursive
```

Configuration keys are in `src/main/resources/application.properties`. Supply environment-specific values through your deployment configuration; do not commit credentials. The primary settings are:

| Setting | Purpose |
| --- | --- |
| `neo4j.url`, `neo4j.user`, `neo4j.password` | Neo4j connection |
| `es.host`, `es.port`, `es.scheme` | OpenSearch connection |
| `es.sign.requests`, `es.region`, `es.service_name` | Optional signed OpenSearch requests |
| `graphql.schema`, `graphql.es_schema` | Private GraphQL schemas |
| `graphql.public.schema`, `graphql.public.es_schema` | Public GraphQL schemas |
| `allow_graphql_query`, `allow_graphql_mutation` | GraphQL operation controls |
| `redis.enable`, `redis.host`, `redis.port` | Optional Redis configuration |
| `auth.enabled`, `auth.endpoint` | Optional request authentication |

The PopSci GraphQL schemas are in `src/main/resources/graphql`, and OpenSearch query/index definitions are in `src/main/resources/yaml`.

## Build And Run

Select JDK 25 as your active Java version using your operating system or IDE settings, and verify that `java -version` reports Java 25.

Install the application WAR and POM into your local Maven repository:

```sh
./mvnw clean install
```

Then start the application:

```sh
./mvnw spring-boot:run
```

With the application running, `GET http://localhost:8080/ping` should return `pong`. GraphQL requests use `POST /v1/graphql/` (private) or `POST /v1/public-graphql/` (public). Queries requiring Neo4j or OpenSearch need those services to be reachable.

The production Dockerfile builds the WAR and deploys it as `ROOT` on Tomcat 11. CI tests with JDK 25 and the image workflow builds and scans the container before publishing it. Network environments that intercept Maven Central TLS must provide trusted CA configuration to the Docker builder; do not disable certificate verification.
