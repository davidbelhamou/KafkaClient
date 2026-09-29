# Task Plan — ClarityIngestClient

Python package with sync and async Kafka producer clients for sending rows to the data lakehouse ingestion topic.

[] 1. Build the transfer CI per rules/transfer_ci.md
[] 2. Project skeleton
[] 3. Error classes and error code table
[] 4. Config validation and librdkafka settings
[] 5. Header validation
[] 6. Row serialization to JSON
[] 7. Sync Producer: produce, produce_and_wait, flush, close
[] 8. Async Producer with the same interface
[] 9. Integration tests against a real Kafka broker
[] 10. README with usage examples and error codes
[] 11. Packaging: build the wheel and document the Artifactory upload
