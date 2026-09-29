# ClarityIngestClient — design

## Purpose

Users of the data lakehouse send events to Kafka. A NiFi pipeline consumes the
topic and writes each event to an Iceberg table. Today every user writes their own
Kafka client, and they get the headers and settings wrong in different ways.

ClarityIngestClient is an installable Python package that sends events correctly
in a few lines. It offers a sync client and an async client with the same
interface.

- Distribution name: `ClarityIngestClient` (`pip install ClarityIngestClient`)
- Import name: `clarity_ingest_client`
- Users: Python developers of any experience level, working on Windows.

## Constraints

- **Few dependencies.** The package runs in a plain Python environment: no Docker
  image, no system libraries beyond what `pip install` brings.
- **Artifactory only.** Dependencies come from the internal Artifactory mirror.
- **Same interface for sync and async.** Same class shapes, method names,
  arguments, errors and delivery semantics.
- **Hard to misuse.** Anything the user can get wrong is validated before sending,
  and fails with an error code and a one-line hint.

## Message contract with NiFi

- **One row per Kafka message.** Never an array or bulk payload. Sending many rows
  means many `produce` calls, one message each.
- **Value:** the row, a `dict`, encoded as UTF-8 JSON (see Serialization).
- **Headers:** passed by the user as a `dict`. Two headers are required:
  - the target table (which Iceberg table the event goes to)
  - `publishTime`

  The library validates that both are present and well-formed, then encodes all
  header values to bytes. Extra headers are passed through unchanged.

## Public interface

Two ways to send one row, plus flush and close. Sync and async share the names.

| Method | Blocks until | Returns | Use when |
|---|---|---|---|
| `produce(row, headers)` | the row is queued locally | a delivery handle | throughput matters; many rows |
| `produce_and_wait(row, headers)` | the broker acknowledges the row | a delivery report, or raises | one row at a time; simplest correct choice |
| `flush(timeout)` | every queued row is acknowledged or failed | a flush result listing failures | end of a batch of `produce` calls |
| `close()` | `flush` has run, then the client is shut | nothing | always; the context manager does it |

```python
from clarity_ingest_client import Producer, AsyncProducer, ClarityError, DeliveryError

headers = {"<table header>": "sales.orders", "publishTime": "<see open questions>"}

# Sync
with Producer(
    bootstrap_servers="broker1:9093,broker2:9093",
    topic="<topic given by the lakehouse team>",
    username="<given by the lakehouse team>",
    password="<given by the lakehouse team>",
) as producer:

    # One row, wait for the broker. Raises on failure.
    report = producer.produce_and_wait({"order_id": 1, "amount": 9.5}, headers=headers)
    print(report.partition, report.offset)

    # Many rows: queue them all, then wait once.
    handles = [producer.produce(row, headers=headers) for row in rows]
    result = producer.flush(timeout=30)
    for failure in result.failed:               # handle, row index and error
        print(failure.error.code, failure.error.hint, failure.error.retriable)

    # Or look at one handle
    handles[0].done()        # acknowledged or failed yet?
    handles[0].result()      # blocks; returns the report or raises its DeliveryError
# Leaving the block calls close(), which flushes first.

# Async: same names. produce() awaits only for local queue space.
async with AsyncProducer(bootstrap_servers=..., topic=..., username=..., password=...) as producer:
    report = await producer.produce_and_wait(row, headers=headers)
    handle = await producer.produce(row, headers=headers)   # handle is awaitable
    report = await handle
    result = await producer.flush(timeout=30)
```

### Behaviour

- **Validation happens before queuing.** Both `produce` and `produce_and_wait` check
  the headers and serialize the row first. A bad row raises `HeaderError` or
  `SerializationError` at once and nothing is queued. A caller always learns about
  their own mistakes at the call site.
- **`produce` never fails silently.** A delivery failure lands in its handle, in the
  next `flush` result, and, if nobody looked at it, in a warning log with a code at
  `close`.
- **Optional callback.** `produce(..., on_delivery=fn)` calls `fn(report, error)`
  when the row is acknowledged or fails. In the sync client it runs on the
  library's background thread, so it must be quick. In the async client it runs
  on the event loop.
- **Background delivery.** The sync client runs one background thread that serves
  delivery reports. The async client resolves its futures on the event loop from
  that same thread. Neither needs the user to call `poll`.
- **Closing** flushes pending rows, then shuts the client. Using a closed client
  raises `ClosedError`. A client garbage-collected without being closed logs a
  warning with a code.

## Delivery and retries

The library does not add its own retry loop. librdkafka already retries every
retriable failure (broker down, leader change, network error) until
`delivery_timeout` runs out. Idempotence is on, so those retries never duplicate or
reorder rows. A second retry loop on top would only add duplicates and hide
latency.

What the caller sees:

| Situation | What happens | Retriable by the caller |
|---|---|---|
| Bad headers or a row that can't be encoded | Raised at the call, nothing queued | No: fix the row |
| Local queue full | `produce` waits up to `queue_timeout`, then raises `QueueFullError` | Yes: slow down, flush, retry |
| Broker unreachable, leader change, network error | Retried inside librdkafka until `delivery_timeout` | Only after `DeliveryTimeoutError` |
| Delivery timeout reached | `DeliveryTimeoutError` | Yes, but see the duplicate note |
| Wrong username or password | `AuthenticationError` | No: fix the credentials |
| Row too large, topic missing, not authorized for topic | `DeliveryError` naming the cause | No |

Every error has a `retriable` attribute, so a caller can decide without knowing
Kafka's error codes.

**Duplicate note.** After a delivery timeout the row may or may not have reached
Kafka. Retrying it can write it twice. Whether that matters depends on how the
pipeline handles duplicates (see open questions).

## Kafka library: confluent-kafka

| Candidate | Type | Runtime deps | Sync | Async |
|---|---|---|---|---|
| confluent-kafka | Bindings to librdkafka, bundled in the wheel | none beyond the wheel | yes | experimental in recent releases |
| kafka-python | Pure Python | none (compression codecs optional) | yes | no |
| aiokafka | Python, optional C extensions | async-timeout (older Pythons), packaging | no | yes |

Chosen: **confluent-kafka**.

- One dependency serves both clients. The async client wraps the same producer and
  resolves asyncio futures from its delivery callbacks, so both clients behave
  identically. We do not rely on confluent-kafka's experimental asyncio producer.
  - Its Windows wheels bundle librdkafka, so a plain `pip install` needs no system
    libraries.
- It is the most reliable option for acknowledgements, idempotence and retries.
- It is available in Artifactory.

Rejected: kafka-python + aiokafka. Two libraries with different internals would make
us responsible for keeping retry, timeout and error behaviour identical across the
two clients.

## Serialization

- The row must be a `dict` with string keys.
- Encoded as UTF-8 JSON. The encoder handles `datetime`, `date`, `Decimal` and
  `UUID` in one fixed format, so every user produces the same thing. The formats
  must match what NiFi's record reader expects (see open questions).
- A value that cannot be encoded raises a serialization error naming the field,
  before anything is sent.
- No custom serializer in the first version: NiFi expects one format.

## Configuration

| Setting | Required | Notes |
|---|---|---|
| `bootstrap_servers` | yes | Comma-separated `host:port` list |
| `topic` | yes | Given to the user by the lakehouse team |
| `username`, `password` | yes | Given by the lakehouse team. Mechanism is always SASL PLAIN. |
| TLS settings | open | Depends on whether the brokers use SASL_SSL or SASL_PLAINTEXT |
| `client_id` | no | Defaults to a name identifying the library |
| `delivery_timeout` | no | Seconds librdkafka keeps retrying a row before `DeliveryTimeoutError` |
| `queue_timeout` | no | Seconds `produce` waits for local queue space before `QueueFullError` |

Fixed by the library, not configurable: SASL mechanism PLAIN, `acks=all`,
idempotence on. Users cannot weaken delivery guarantees.

## Errors

Every error the library raises or logs carries a short unique code, a one-line
hint, and a `retriable` flag. Air-gap rule: users report errors by code, so codes
are never renumbered or reused.

- `ClarityError`: the base of everything the library raises.
  - `ConfigError`: bad or missing settings, raised by the constructor.
  - `HeaderError`: a required header is missing or malformed.
  - `SerializationError`: the row can't be encoded; names the field.
  - `QueueFullError`: the local queue stayed full for `queue_timeout`.
  - `DeliveryError`: the broker did not take the row; carries the Kafka error name.
    - `DeliveryTimeoutError`: librdkafka's retries ran out.
    - `AuthenticationError`: the username or password was rejected.
  - `ClosedError`: the client was used after `close`.

The code table is allocated during implementation and kept in the package docs.

## Open questions

1. Exact name of the target-table header.
2. `publishTime` format: epoch milliseconds as a string, epoch milliseconds as
   8 bytes, or ISO 8601? Should the library fill it in when the user leaves it out?
3. Do the brokers use SASL_SSL (TLS) or SASL_PLAINTEXT? With TLS, do users need a CA
   file, or is the CA in the Windows certificate store?
4. JSON formats NiFi expects for dates, timestamps and decimals.
5. Is there a table-name format to validate (for example `namespace.table`)?
6. Does NiFi or the Iceberg write deduplicate rows? If not, a caller retrying after
   `DeliveryTimeoutError` can create duplicate rows.
