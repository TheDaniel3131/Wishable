package main

// client/main.go — CLI task submitter
//
// Usage:
//   go run ./client/main.go --type email --payload '{"to":"user@example.com"}' --priority 5
//   go run ./client/main.go --bench 50    # submit 50 random tasks

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "github.com/grpc-taskqueue/proto"
)

var taskTypes = []string{"email", "resize_image", "transcode", "report", "notification", "backup"}

func randomPayload(taskType string) string {
	payloads := map[string]interface{}{
		"email":        map[string]string{"to": "user@example.com", "subject": "Hello"},
		"resize_image": map[string]interface{}{"url": "s3://bucket/img.jpg", "width": 1280, "height": 720},
		"transcode":    map[string]interface{}{"input": "s3://bucket/video.mp4", "codec": "h264"},
		"report":       map[string]string{"type": "monthly", "format": "pdf"},
		"notification": map[string]string{"user_id": "u123", "channel": "push"},
		"backup":       map[string]string{"source": "/data", "dest": "s3://backups"},
	}
	p, _ := json.Marshal(payloads[taskType])
	return string(p)
}

func main() {
	server   := flag.String("server", "localhost:50051", "gRPC server address")
	taskType := flag.String("type", "email", "task type")
	payload  := flag.String("payload", "", "JSON payload (auto-generated if empty)")
	priority := flag.Int("priority", 5, "priority 1–10")
	bench    := flag.Int("bench", 0, "submit N random tasks")
	watch    := flag.Bool("watch", false, "watch live events after submitting")
	flag.Parse()

	conn, err := grpc.Dial(*server, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	client := pb.NewTaskQueueClient(conn)
	ctx := context.Background()

	if *bench > 0 {
		log.Printf("Submitting %d random tasks...", *bench)
		for i := 0; i < *bench; i++ {
			t := taskTypes[rand.Intn(len(taskTypes))]
			resp, err := client.SubmitTask(ctx, &pb.SubmitRequest{
				Task: &pb.Task{
					Type:     t,
					Payload:  randomPayload(t),
					Priority: int32(1 + rand.Intn(10)),
				},
			})
			if err != nil {
				log.Printf("  [%d] error: %v", i, err)
				continue
			}
			log.Printf("  [%d] submitted task=%s type=%s", i, resp.TaskId, t)
			time.Sleep(50 * time.Millisecond)
		}
		fmt.Println("\ndone. start a worker to process them:")
		fmt.Println("   go run ./worker/main.go --server", *server)
	} else {
		p := *payload
		if p == "" {
			p = randomPayload(*taskType)
		}
		resp, err := client.SubmitTask(ctx, &pb.SubmitRequest{
			Task: &pb.Task{
				Type:     *taskType,
				Payload:  p,
				Priority: int32(*priority),
			},
		})
		if err != nil {
			log.Fatalf("submit: %v", err)
		}
		fmt.Printf("submitted task_id=%s accepted=%v\n", resp.TaskId, resp.Accepted)
	}

	if *watch {
		fmt.Println("\nwatching events (ctrl-c to stop)...")
		stream, err := client.WatchEvents(ctx, &pb.WatchRequest{})
		if err != nil {
			log.Fatalf("watch: %v", err)
		}
		for {
			ev, err := stream.Recv()
			if err != nil {
				log.Fatalf("watch recv: %v", err)
			}
			switch ev.Type {
			case pb.QueueEvent_TASK_SUBMITTED:
				fmt.Printf("  SUBMITTED  task=%s\n", ev.TaskId)
			case pb.QueueEvent_TASK_ASSIGNED:
				fmt.Printf("  ASSIGNED   task=%s worker=%s\n", ev.TaskId, ev.WorkerId)
			case pb.QueueEvent_TASK_PROGRESS:
				if ev.Progress != nil {
					fmt.Printf("  PROGRESS   task=%s %d%%  %s\n",
						ev.TaskId, ev.Progress.Percent, ev.Progress.Message)
				}
			case pb.QueueEvent_TASK_COMPLETED:
				fmt.Printf("  COMPLETED  task=%s worker=%s dur=%dms\n",
					ev.TaskId, ev.WorkerId, ev.Result.DurationMs)
			case pb.QueueEvent_TASK_FAILED:
				fmt.Printf("  FAILED     task=%s err=%s\n", ev.TaskId, ev.Result.Error)
			case pb.QueueEvent_WORKER_JOINED:
				fmt.Printf("  WORKER_IN  id=%s\n", ev.WorkerId)
			case pb.QueueEvent_WORKER_LEFT:
				fmt.Printf("  WORKER_OUT id=%s\n", ev.WorkerId)
			}
		}
	}
}
