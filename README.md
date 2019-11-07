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
