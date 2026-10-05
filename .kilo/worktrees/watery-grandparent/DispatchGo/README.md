# gRPC Task Queue

A distributed background-job processing system built with **Go + gRPC**, featuring:

- Priority queue with worker auto-dispatch
- Bidirectional streaming worker connections
- Server-side event fan-out for live dashboards
- Real-time progress reporting
- Automatic task re-queue on worker disconnect

---

## Architecture

```
 ┌──────────────┐          ┌─────────────────────────┐
 │   CLI Client │──Submit──▶                         │
 └──────────────┘          │                         │
                           │    gRPC Server          │◀──WatchEvents──┐
 ┌──────────────┐          │    (port 50051)         │                │
 │   Worker 1   │◀─Tasks───│                         │  ┌─────────────┴──┐
 │   Worker 2   │──Results─▶    Priority Queue       │  │  Dashboard     │
 │   Worker 3   │──Progress▶    Worker Registry      │  │  (React)       │
 └──────────────┘          │    Event Bus            │  └────────────────┘
                           └─────────────────────────┘
```

## gRPC Service — All 4 Patterns

| RPC | Pattern | Purpose |
|-----|---------|---------|
| `SubmitTask` | Unary | Enqueue a task |
| `WorkerStream` | **Bidi streaming** | Worker pulls tasks ← server, sends results → server |
| `ReportProgress` | Unary | Worker reports incremental progress |
| `WatchEvents` | **Server streaming** | Fan-out live events to dashboard(s) |
| `GetStats` | Unary | Queue snapshot |

---

## Quick Start

### 1. Generate proto bindings
```bash
# Install protoc plugins if needed:
# go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
# go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

protoc --go_out=. --go-grpc_out=. proto/taskqueue.proto
```

### 2. Install dependencies
```bash
go mod tidy
```

### 3. Start the server
```bash
go run ./server/main.go --port 50051
```

### 4. Start workers (multiple terminals)
```bash
go run ./worker/main.go --server localhost:50051 --id worker-1
go run ./worker/main.go --server localhost:50051 --id worker-2
go run ./worker/main.go --server localhost:50051 --id worker-3
```

### 5. Submit tasks
```bash
# Single task
go run ./client/main.go --type email --priority 8

# Benchmark: 50 random tasks
go run ./client/main.go --bench 50

# Submit + watch live events
go run ./client/main.go --type transcode --watch
```

---

## Project Structure

```
grpc-taskqueue/
├── proto/
│   └── taskqueue.proto       # Service definition (all message + RPC types)
├── server/
│   └── main.go               # gRPC server — queue, dispatcher, event bus
├── worker/
│   └── main.go               # Worker — bidi stream, task processors
├── client/
│   └── main.go               # CLI — submit tasks, watch events
├── go.mod
└── README.md
```

---

## Key Design Decisions

**Bidirectional streaming for workers** — A single long-lived stream handles both
task delivery and result acknowledgment per worker. This avoids polling and lets
the server push tasks immediately when they become available.

**Priority queue** — Tasks are inserted in priority order (1–10). `tryDispatch()`
is called on every submit and worker registration to immediately match pending
tasks to available workers.

**Fan-out event bus** — `WatchEvents` uses a channel per subscriber. Events are
broadcast to all connected dashboards without blocking the hot path. Slow
consumers drop events rather than back-pressuring the server.

**Task re-queue on disconnect** — When a worker stream closes, any `running` tasks
assigned to it are atomically moved back to `pending` and `tryDispatch()` fires
again to reassign them.

---

## Production Extensions

- Replace in-memory state with **Redis** (sorted sets for priority queue)
- Add **TLS** + **mTLS** for worker authentication
- Use **Envoy + grpc-web** to connect browser dashboards directly
- Add **dead-letter queue** for repeatedly failing tasks
- Expose **Prometheus metrics** via the stats endpoint
- Deploy workers as **Kubernetes Deployments** with HPA
