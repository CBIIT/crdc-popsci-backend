package gov.nih.nci.bento;

import graphql.ExecutionInput;
import graphql.ExecutionResult;
import graphql.GraphQL;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.neo4j.graphql.Cypher;
import org.neo4j.graphql.DataFetchingInterceptor;
import org.neo4j.graphql.SchemaBuilder;
import org.neo4j.graphql.SchemaConfig;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

/** Executes the real schema, Cypher generator and property fetchers without a database.
 * Only the database result is supplied by the interceptor. Introspection alone cannot
 * detect binary incompatibilities in property fetchers.
 */
class GraphQLDependencyCompatibilityTest {
    private static final String PRIVATE_SCHEMA = "graphql/bento-extended.graphql";

    @ParameterizedTest
    @ValueSource(booleans = {false, true})
    void generatedRelationshipsResolvePropertiesAndAliases(boolean aliases) throws Exception {
        List<Cypher> generated = new ArrayList<>();
        String idKey = aliases ? "id" : "program_id";
        String studiesKey = aliases ? "children" : "studies";
        String studyKey = aliases ? "id" : "study_id";
        Map<String, Object> record = Map.of(idKey, "P1", studiesKey, List.of(Map.of(studyKey, "S1")));
        GraphQL graphQL = graphQL(PRIVATE_SCHEMA, (env, fetcher) -> {
            generated.add(fetcher.get(env));
            assertEquals("P1", env.getVariables().get("id"));
            return List.of(record);
        });
        String selection = aliases
                ? "id: program_id children: studies { id: study_id }"
                : "program_id studies { study_id }";
        ExecutionResult result = graphQL.execute(ExecutionInput.newExecutionInput()
                .query("query($id: String) { rows: program(program_id: $id, first: 1) { " + selection + " } }")
                .variables(Map.of("id", "P1")).build());

        assertNoErrors(result);
        assertEquals(Map.of("rows", List.of(record)), result.getData());
        assertEquals(1, generated.size());
        assertTrue(generated.getFirst().getQuery().contains("study_of_program"));
        assertFalse(generated.getFirst().getParams().isEmpty());
    }

    @Test
    void frontendNodeCountsQueryExecutesCypherAndReadsReturnedMap() throws Exception {
        List<Cypher> generated = new ArrayList<>();
        Map<String, Object> counts = Map.of("numberOfPrograms", 1, "numberOfStudies", 2,
                "numberOfSubjects", 3, "numberOfSamples", 4, "numberOfFiles", 5, "numberOfLabProcedures", 6);
        GraphQL graphQL = graphQL(PRIVATE_SCHEMA, (env, fetcher) -> {
            generated.add(fetcher.get(env));
            return counts;
        });
        ExecutionResult result = graphQL.execute(ExecutionInput.newExecutionInput().query("""
                query nodeCounts($subject_ids: [String] = [], $sample_ids: [String] = [],
                                 $file_ids: [String] = [], $file_names: [String] = []) {
                    nodeCountsFromLists(subject_ids: $subject_ids, sample_ids: $sample_ids,
                                        file_ids: $file_ids, file_names: $file_names) {
                        numberOfPrograms numberOfStudies numberOfSubjects
                        numberOfSamples numberOfFiles numberOfLabProcedures
                    }
                }
                """).variables(Map.of("subject_ids", List.of("SS1"))).build());

        assertNoErrors(result);
        assertEquals(Map.of("nodeCountsFromLists", counts), result.getData());
        assertEquals(1, generated.size());
        assertTrue(generated.getFirst().getQuery().contains("COUNT(DISTINCT"));
        assertFalse(generated.getFirst().getParams().isEmpty());
    }

    @Test
    void publicCypherFieldExecutesWithRootAlias() throws Exception {
        List<Cypher> generated = new ArrayList<>();
        GraphQL graphQL = graphQL("graphql/bento-extended-public.graphql", (env, fetcher) -> {
            generated.add(fetcher.get(env));
            return "1.0.0";
        });
        ExecutionResult result = graphQL.execute("{ version: schemaVersion }");
        assertNoErrors(result);
        assertEquals(Map.of("version", "1.0.0"), result.getData());
        assertEquals(1, generated.size());
        assertTrue(generated.getFirst().getQuery().contains("1.0.0"));
    }

    private GraphQL graphQL(String resource, DataFetchingInterceptor interceptor) throws IOException {
        try (var stream = getClass().getClassLoader().getResourceAsStream(resource)) {
            assertNotNull(stream, resource);
            String sdl = new String(stream.readAllBytes(), StandardCharsets.UTF_8);
            return GraphQL.newGraphQL(SchemaBuilder.buildSchema(sdl, new SchemaConfig(), interceptor)).build();
        }
    }

    private void assertNoErrors(ExecutionResult result) {
        assertTrue(result.getErrors().isEmpty(), () -> result.getErrors().toString());
    }
}
