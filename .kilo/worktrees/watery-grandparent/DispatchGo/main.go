package main

// server/main.go — gRPC Task Queue Server
//
// Run:  go run ./server/main.go --port 50051
//
// This file contains the full server implementation.  In a real project you
// would split it into packages; here everything lives in one file so it is
// easy to read and run directly.
//
// ─────────────────────────────────────────────────────────────────────────────
//  Dependencies (add to go.mod / go.sum with `go mod tidy`):
//    google.golang.org/grpc
//    google.golang.org/protobuf
//
//  Generate proto bindings:
//    protoc --go_out=. --go-grpc_out=. proto/taskqueue.proto
// ─────────────────────────────────────────────────────────────────────────────

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"net"
	"sync"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/reflection"
	"google.golang.org/grpc/status"

	pb "github.com/grpc-taskqueue/proto"
)

// ─── In-memory state ─────────────────────────────────────────────────────────

type taskState int

const (
	statePending   taskState = iota
	stateRunning
	stateCompleted
	stateFailed
)

type taskRecord struct {
	task      *pb.Task
	state     taskState
	workerID  string
	result    *pb.TaskResult
	createdAt time.Time
}

type workerConn struct {
	info     *pb.WorkerInfo
	taskCh   chan *pb.Task // tasks sent down to this worker
	joinedAt time.Time
}

type server struct {
	pb.UnimplementedTaskQueueServer

	mu      sync.RWMutex
	tasks   map[string]*taskRecord     // task_id → record
	workers map[string]*workerConn     // worker_id → conn
	pending []*pb.Task                 // priority-ordered queue

	// fan-out: watchers receive every QueueEvent
	watchMu   sync.RWMutex
	watchers  map[string]chan *pb.QueueEvent

	completedCount int
	failedCount    int
	completedTimes []time.Time // for throughput calculation
}

func newServer() *server {
	return &server{
		tasks:    make(map[string]*taskRecord),
		workers:  make(map[string]*workerConn),
		watchers: make(map[string]chan *pb.QueueEvent),
	}
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

func randomID() string {
	return fmt.Sprintf("%x", rand.Int63())
}

func nowMillis() int64 {
	return time.Now().UnixMilli()
}

func (s *server) broadcast(ev *pb.QueueEvent) {
	ev.Timestamp = nowMillis()
	s.watchMu.RLock()
	defer s.watchMu.RUnlock()
	for _, ch := range s.watchers {
		select {
		case ch <- ev:
		default: // drop if slow consumer
		}
	}
}

// tryDispatch checks pending tasks and available workers and assigns work.
// Must be called with s.mu held (write lock).
func (s *server) tryDispatch() {
	for len(s.pending) > 0 {
		task := s.pending[0]

		// find an idle worker that supports the task type
		var chosen *workerConn
		for _, w := range s.workers {
			for _, t := range w.info.SupportedTypes {
				if t == task.Type || t == "*" {
					chosen = w
					break
				}
			}
			if chosen != nil {
				break
			}
		}
		if chosen == nil {
			break // no suitable worker right now
		}

		s.pending = s.pending[1:]
		rec := s.tasks[task.Id]
		rec.state = stateRunning
		rec.workerID = chosen.info.WorkerId

		// non-blocking send (worker stream is buffered)
		select {
		case chosen.taskCh <- task:
		default:
			// worker buffer full — re-queue
			rec.state = statePending
			rec.workerID = ""
			s.pending = append([]*pb.Task{task}, s.pending...)
			break
		}

		go s.broadcast(&pb.QueueEvent{
			Type:     pb.QueueEvent_TASK_ASSIGNED,
			TaskId:   task.Id,
			WorkerId: chosen.info.WorkerId,
		})
	}
}

// ─── RPC: SubmitTask ─────────────────────────────────────────────────────────

func (s *server) SubmitTask(_ context.Context, req *pb.SubmitRequest) (*pb.SubmitResponse, error) {
	if req.Task == nil {
		return nil, status.Error(codes.InvalidArgument, "task required")
	}
	task := req.Task
	if task.Id == "" {
		task.Id = randomID()
	}
	task.CreatedAt = nowMillis()

	s.mu.Lock()
	s.tasks[task.Id] = &taskRecord{task: task, state: statePending, createdAt: time.Now()}
	// insert in priority order (descending)
	inserted := false
	for i, t := range s.pending {
		if task.Priority > t.Priority {
			s.pending = append(s.pending[:i], append([]*pb.Task{task}, s.pending[i:]...)...)
			inserted = true
			break
		}
	}
	if !inserted {
		s.pending = append(s.pending, task)
	}
	s.tryDispatch()
	s.mu.Unlock()

	go s.broadcast(&pb.QueueEvent{
		Type:   pb.QueueEvent_TASK_SUBMITTED,
		TaskId: task.Id,
	})

	log.Printf("[SUBMIT] task=%s type=%s priority=%d", task.Id, task.Type, task.Priority)
	return &pb.SubmitResponse{TaskId: task.Id, Accepted: true}, nil
}

// ─── RPC: WorkerStream (bidirectional) ───────────────────────────────────────

func (s *server) WorkerStream(stream pb.TaskQueue_WorkerStreamServer) error {
	// First message is an AckRequest with a nil result acting as registration.
	// Workers send AckRequest{result: nil} initially; we use WorkerInfo from
	// the first non-nil result's worker_id — so we need an out-of-band
	// registration.  We handle this with metadata or an empty-result sentinel.
	//
	// For simplicity we read the first message to extract the worker_id, then
	// register.  Workers must send a sentinel AckRequest{result: &TaskResult{worker_id:"..."}}
	// with an empty task_id to register.

	first, err := stream.Recv()
	if err != nil {
		return err
	}
	if first.Result == nil || first.Result.WorkerId == "" {
		return status.Error(codes.InvalidArgument, "first message must contain worker info via result.worker_id")
	}

	workerID := first.Result.WorkerId

	// Parse supported types from task_id field (hack-friendly for demo)
	// In production, extend the proto or use initial metadata.
	supportedTypes := []string{"*"}
	hostname := "unknown"

	conn := &workerConn{
		info: &pb.WorkerInfo{
			WorkerId:       workerID,
			Hostname:       hostname,
			SupportedTypes: supportedTypes,
			Concurrency:    4,
		},
		taskCh:   make(chan *pb.Task, 16),
		joinedAt: time.Now(),
	}

	s.mu.Lock()
	s.workers[workerID] = conn
	s.tryDispatch()
	s.mu.Unlock()

	go s.broadcast(&pb.QueueEvent{
		Type:     pb.QueueEvent_WORKER_JOINED,
		WorkerId: workerID,
		Worker:   conn.info,
	})
	log.Printf("[WORKER] joined worker=%s", workerID)

	// goroutine: forward tasks down to the worker
	sendErr := make(chan error, 1)
	go func() {
		for {
			select {
			case task, ok := <-conn.taskCh:
				if !ok {
					sendErr <- nil
					return
				}
				if err := stream.Send(task); err != nil {
					sendErr <- err
					return
				}
				log.Printf("[DISPATCH] task=%s → worker=%s", task.Id, workerID)
			case <-stream.Context().Done():
				sendErr <- stream.Context().Err()
				return
			}
		}
	}()

	// main goroutine: receive completed task results
	recvLoop:
	for {
		select {
		case err := <-sendErr:
			if err != nil {
				log.Printf("[WORKER] send error worker=%s: %v", workerID, err)
			}
			break recvLoop
		default:
		}

		ack, err := stream.Recv()
		if err != nil {
			break recvLoop
		}
		if ack.Result == nil || ack.Result.TaskId == "" {
			continue // ping / keepalive
		}

		res := ack.Result
		log.Printf("[RESULT] task=%s worker=%s success=%v dur=%dms",
			res.TaskId, res.WorkerId, res.Success, res.DurationMs)

		s.mu.Lock()
		if rec, ok := s.tasks[res.TaskId]; ok {
			rec.result = res
			if res.Success {
				rec.state = stateCompleted
				s.completedCount++
				s.completedTimes = append(s.completedTimes, time.Now())
			} else {
				rec.state = stateFailed
				s.failedCount++
			}
		}
		s.mu.Unlock()

		evType := pb.QueueEvent_TASK_COMPLETED
		if !res.Success {
			evType = pb.QueueEvent_TASK_FAILED
		}
		go s.broadcast(&pb.QueueEvent{
			Type:     evType,
			TaskId:   res.TaskId,
			WorkerId: res.WorkerId,
			Result:   res,
		})
	}

	// cleanup
	s.mu.Lock()
	delete(s.workers, workerID)
	// re-queue any tasks that were assigned to this worker but not completed
	for _, rec := range s.tasks {
		if rec.workerID == workerID && rec.state == stateRunning {
			rec.state = statePending
			rec.workerID = ""
			s.pending = append([]*pb.Task{rec.task}, s.pending...)
		}
	}
	s.tryDispatch()
	s.mu.Unlock()

	go s.broadcast(&pb.QueueEvent{
		Type:     pb.QueueEvent_WORKER_LEFT,
		WorkerId: workerID,
	})
	log.Printf("[WORKER] left worker=%s", workerID)
	return nil
}

// ─── RPC: ReportProgress ─────────────────────────────────────────────────────

func (s *server) ReportProgress(_ context.Context, p *pb.TaskProgress) (*pb.AckResponse, error) {
	go s.broadcast(&pb.QueueEvent{
		Type:     pb.QueueEvent_TASK_PROGRESS,
		TaskId:   p.TaskId,
		WorkerId: p.WorkerId,
		Progress: p,
	})
	return &pb.AckResponse{Ok: true}, nil
}

// ─── RPC: WatchEvents (server-side stream) ───────────────────────────────────

func (s *server) WatchEvents(_ *pb.WatchRequest, stream pb.TaskQueue_WatchEventsServer) error {
	id := randomID()
	ch := make(chan *pb.QueueEvent, 64)

	s.watchMu.Lock()
	s.watchers[id] = ch
	s.watchMu.Unlock()

	defer func() {
		s.watchMu.Lock()
		delete(s.watchers, id)
		s.watchMu.Unlock()
	}()

	log.Printf("[WATCH] subscriber %s connected", id)
	for {
		select {
		case ev := <-ch:
			if err := stream.Send(ev); err != nil {
				return err
			}
		case <-stream.Context().Done():
			log.Printf("[WATCH] subscriber %s disconnected", id)
			return nil
		}
	}
}

// ─── RPC: GetStats ───────────────────────────────────────────────────────────

func (s *server) GetStats(_ context.Context, _ *pb.StatsRequest) (*pb.QueueStats, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()

	pending := len(s.pending)
	running := 0
	for _, rec := range s.tasks {
		if rec.state == stateRunning {
			running++
		}
	}

	// throughput: completions in last minute
	cutoff := time.Now().Add(-time.Minute)
	recent := 0
	for _, t := range s.completedTimes {
		if t.After(cutoff) {
			recent++
		}
	}

	return &pb.QueueStats{
		Pending:          int32(pending),
		Running:          int32(running),
		Completed:        int32(s.completedCount),
		Failed:           int32(s.failedCount),
		Workers:          int32(len(s.workers)),
		ThroughputPerMin: float64(recent),
	}, nil
}

// ─── main ─────────────────────────────────────────────────────────────────────

func main() {
	port := flag.Int("port", 50051, "gRPC listen port")
	flag.Parse()

	lis, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	grpcServer := grpc.NewServer(
		grpc.MaxRecvMsgSize(16<<20),
		grpc.MaxSendMsgSize(16<<20),
	)
	pb.RegisterTaskQueueServer(grpcServer, newServer())
	reflection.Register(grpcServer) // enables grpcurl / grpc-ui

	log.Printf("taskqueue server listening on :%d", *port)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
