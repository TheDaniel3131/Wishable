package main

// worker/main.go — gRPC Task Queue Worker
//
// Run multiple instances:
//   go run ./worker/main.go --server localhost:50051 --id worker-1
//   go run ./worker/main.go --server localhost:50051 --id worker-2

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "github.com/grpc-taskqueue/proto"
)

// ─── Fake task processors ─────────────────────────────────────────────────────

type processor func(ctx context.Context, task *pb.Task, progressFn func(int, string)) (string, error)

var processors = map[string]processor{
	"email": func(ctx context.Context, task *pb.Task, progress func(int, string)) (string, error) {
		steps := []string{"Connecting to SMTP", "Rendering template", "Sending", "Logging delivery"}
		for i, step := range steps {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(time.Duration(200+rand.Intn(300)) * time.Millisecond):
			}
			progress((i+1)*25, step)
		}
		return `{"status":"delivered","message_id":"msg-` + randomID() + `"}`, nil
	},
	"resize_image": func(ctx context.Context, task *pb.Task, progress func(int, string)) (string, error) {
		for pct := 10; pct <= 100; pct += 10 {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(time.Duration(100+rand.Intn(200)) * time.Millisecond):
			}
			progress(pct, fmt.Sprintf("Processing chunk %d%%", pct))
		}
		return `{"width":1280,"height":720,"size_kb":142}`, nil
	},
	"transcode": func(ctx context.Context, task *pb.Task, progress func(int, string)) (string, error) {
		stages := []struct {
			pct int
			msg string
		}{
			{10, "Probing input"},
			{30, "Decoding frames"},
			{60, "Encoding H.264"},
			{85, "Muxing audio"},
			{100, "Writing output"},
		}
		for _, s := range stages {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(time.Duration(300+rand.Intn(500)) * time.Millisecond):
			}
			progress(s.pct, s.msg)
		}
		return `{"codec":"h264","duration_s":62,"fps":30}`, nil
	},
	"*": func(ctx context.Context, task *pb.Task, progress func(int, string)) (string, error) {
		// Generic processor — simulates some work
		for pct := 20; pct <= 100; pct += 20 {
			select {
			case <-ctx.Done():
				return "", ctx.Err()
			case <-time.After(time.Duration(150+rand.Intn(350)) * time.Millisecond):
			}
			progress(pct, fmt.Sprintf("Step %d%%", pct))
		}
		var p map[string]interface{}
		_ = json.Unmarshal([]byte(task.Payload), &p)
		return `{"processed":true}`, nil
	},
}

func randomID() string { return fmt.Sprintf("%x", rand.Int63()) }

// ─── Worker ──────────────────────────────────────────────────────────────────

type worker struct {
	id     string
	client pb.TaskQueueClient
	conn   *grpc.ClientConn
}

func newWorker(id, serverAddr string) (*worker, error) {
	conn, err := grpc.Dial(serverAddr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
		grpc.WithTimeout(5*time.Second),
	)
	if err != nil {
		return nil, fmt.Errorf("dial %s: %w", serverAddr, err)
	}
	return &worker{id: id, client: pb.NewTaskQueueClient(conn), conn: conn}, nil
}

func (w *worker) run(ctx context.Context) error {
	stream, err := w.client.WorkerStream(ctx)
	if err != nil {
		return fmt.Errorf("open stream: %w", err)
	}

	// Registration: send sentinel with worker_id
	if err := stream.Send(&pb.AckRequest{
		Result: &pb.TaskResult{WorkerId: w.id},
	}); err != nil {
		return fmt.Errorf("register: %w", err)
	}

	log.Printf("[%s] registered with server", w.id)

	// Semaphore for concurrency
	sem := make(chan struct{}, 4)

	for {
		task, err := stream.Recv()
		if err != nil {
			return fmt.Errorf("recv: %w", err)
		}

		sem <- struct{}{}
		go func(t *pb.Task) {
			defer func() { <-sem }()
			w.process(ctx, stream, t)
		}(task)
	}
}

func (w *worker) process(ctx context.Context, stream pb.TaskQueue_WorkerStreamClient, task *pb.Task) {
	log.Printf("[%s] processing task=%s type=%s", w.id, task.Id, task.Type)
	start := time.Now()

	// Select processor
	proc, ok := processors[task.Type]
	if !ok {
		proc = processors["*"]
	}

	// Intentionally fail 5% of tasks
	if rand.Float32() < 0.05 {
		_ = stream.Send(&pb.AckRequest{Result: &pb.TaskResult{
			TaskId:     task.Id,
			WorkerId:   w.id,
			Success:    false,
			Error:      "simulated random failure",
			DurationMs: time.Since(start).Milliseconds(),
		}})
		return
	}

	progressFn := func(pct int, msg string) {
		_, _ = w.client.ReportProgress(ctx, &pb.TaskProgress{
			TaskId:   task.Id,
			WorkerId: w.id,
			Percent:  int32(pct),
			Message:  msg,
		})
	}

	output, err := proc(ctx, task, progressFn)

	result := &pb.TaskResult{
		TaskId:     task.Id,
		WorkerId:   w.id,
		DurationMs: time.Since(start).Milliseconds(),
	}
	if err != nil {
		result.Success = false
		result.Error = err.Error()
	} else {
		result.Success = true
		result.Output = output
	}

	if sendErr := stream.Send(&pb.AckRequest{Result: result}); sendErr != nil {
		log.Printf("[%s] failed to ack task=%s: %v", w.id, task.Id, sendErr)
	} else {
		log.Printf("[%s] acked task=%s success=%v dur=%dms", w.id, task.Id, result.Success, result.DurationMs)
	}
}

func main() {
	server := flag.String("server", "localhost:50051", "gRPC server address")
	id := flag.String("id", "", "worker ID (default: hostname-pid)")
	flag.Parse()

	if *id == "" {
		hostname, _ := os.Hostname()
		*id = fmt.Sprintf("%s-%d", hostname, os.Getpid())
	}

	w, err := newWorker(*id, *server)
	if err != nil {
		log.Fatalf("create worker: %v", err)
	}
	defer w.conn.Close()

	log.Printf("worker %s connecting to %s", *id, *server)
	if err := w.run(context.Background()); err != nil {
		log.Fatalf("worker error: %v", err)
	}
}
