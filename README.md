# ESLE

## Benchmark Goals
* run tests for database without pgpool
* run tests for 2 or 3 slaves
* run tests for more slaves
* verify that there are no improvements latency for write transactions
* verify improvements for read transactions
* verify how much does the read transactions improve with the number of replicas
* decompose the benchmark to put in the report
  * what is the schema
  * what are the request

## Dependencies
 - docker
 - jq
 - pgbench
 - psql

## Instructions

```bash
cd ./Assignment
./run_benchmarks 0 4
```

This will run pgpool with 0 to 4 replicas and benchmark them. Saving the results to
`./Assignment/results/`
