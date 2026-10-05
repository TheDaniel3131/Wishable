import { useState, useEffect, useRef, useCallback } from "react";

const TASK_TYPES = ["email", "resize_image", "transcode", "report", "notification", "backup"];

const TYPE_HUE = {
  email:        220,
  resize_image: 160,
  transcode:    0,
  report:       45,
  notification: 270,
  backup:       30,
};

function uid() { return Math.random().toString(36).slice(2, 9); }
function randType() { return TASK_TYPES[Math.floor(Math.random() * TASK_TYPES.length)]; }
function randInt(a, b) { return a + Math.floor(Math.random() * (b - a)); }
function fmtMs(ms) {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}
function fmtAge(ts) {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s`;
  return `${Math.floor(s / 60)}m`;
}

function useQueueSimulation() {
  const [tasks, setTasks]     = useState([]);
  const [workers, setWorkers] = useState([]);
  const [events, setEvents]   = useState([]);
  const [stats, setStats]     = useState({ completed: 0, failed: 0, throughput: 0 });
  const taskPool   = useRef([]);
  const workerPool = useRef([]);
  const counters   = useRef({ completed: 0, failed: 0, recentDone: [] });

  const pushEvent = useCallback((ev) => {
    setEvents(prev => [ev, ...prev].slice(0, 80));
  }, []);

  useEffect(() => {
    const ws = [
      { id: "worker-01", host: "node-a.internal", load: 0, capacity: 4 },
      { id: "worker-02", host: "node-b.internal", load: 0, capacity: 3 },
      { id: "worker-03", host: "node-c.internal", load: 0, capacity: 2 },
    ];
    workerPool.current = ws;
    setWorkers([...ws]);
    ws.forEach(w => pushEvent({ type: "WORKER_JOINED", workerId: w.id, ts: Date.now() }));
  }, []);

  useEffect(() => {
    const interval = setInterval(() => {
      const submitCount = Math.random() < 0.6 ? randInt(0, 3) : 0;
      for (let i = 0; i < submitCount; i++) {
        const t = {
          id: uid(),
          type: randType(),
          priority: randInt(1, 11),
          status: "pending",
          progress: 0,
          workerId: null,
          createdAt: Date.now(),
          completedAt: null,
        };
        taskPool.current.push(t);
        pushEvent({ type: "TASK_SUBMITTED", taskId: t.id, taskType: t.type, priority: t.priority, ts: Date.now() });
      }

      taskPool.current.forEach(t => {
        if (t.status !== "running") return;
        t.progress = Math.min(100, t.progress + randInt(7, 22));
        if (t.progress >= 100) {
          const fail = Math.random() < 0.07;
          t.status = fail ? "failed" : "completed";
          t.completedAt = Date.now();
          const w = workerPool.current.find(w => w.id === t.workerId);
          if (w) w.load = Math.max(0, w.load - 1);
          if (fail) {
            counters.current.failed++;
            pushEvent({ type: "TASK_FAILED", taskId: t.id, workerId: t.workerId, ts: Date.now() });
          } else {
            counters.current.completed++;
            counters.current.recentDone.push(Date.now());
            pushEvent({ type: "TASK_COMPLETED", taskId: t.id, workerId: t.workerId, dur: t.completedAt - t.createdAt, ts: Date.now() });
          }
        }
      });

      taskPool.current
        .filter(t => t.status === "pending")
        .sort((a, b) => b.priority - a.priority)
        .forEach(t => {
          const w = workerPool.current.find(w => w.load < w.capacity);
          if (!w) return;
          t.status = "running";
          t.workerId = w.id;
          w.load++;
          pushEvent({ type: "TASK_ASSIGNED", taskId: t.id, workerId: w.id, ts: Date.now() });
        });

      const terminal = taskPool.current.filter(t => t.status === "completed" || t.status === "failed");
      const active   = taskPool.current.filter(t => t.status === "pending" || t.status === "running");
      taskPool.current = [...active, ...terminal.slice(-50)];

      const cutoff = Date.now() - 60_000;
      counters.current.recentDone = counters.current.recentDone.filter(t => t > cutoff);

      setTasks([...taskPool.current].reverse());
      setWorkers([...workerPool.current]);
      setStats({
        completed: counters.current.completed,
        failed: counters.current.failed,
        throughput: counters.current.recentDone.length,
      });
    }, 700);
    return () => clearInterval(interval);
  }, []);

  return { tasks, workers, events, stats };
}

function Sparkline({ values }) {
  if (values.length < 2) return <div style={{ width: 80, height: 24 }} />;
  const max = Math.max(...values, 1);
  const w = 80, h = 24;
  const pts = values
    .map((v, i) => `${(i / (values.length - 1)) * w},${h - (v / max) * (h - 3) - 1}`)
    .join(" ");
  return (
    <svg width={w} height={h} style={{ display: "block", flexShrink: 0, overflow: "visible" }}>
      <polyline points={pts} fill="none" stroke="#4caf82" strokeWidth="1.5" strokeLinejoin="round" strokeLinecap="round" />
    </svg>
  );
}

function Bar({ pct, color = "#5b9cf6" }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
      <div style={{ flex: 1, height: 2, background: "#1e2025", borderRadius: 1, overflow: "hidden" }}>
        <div style={{ width: `${pct}%`, height: "100%", background: color, transition: "width 0.3s linear" }} />
      </div>
      <span style={{ fontFamily: "IBM Plex Mono, monospace", fontSize: 10, color: "#4a4f5a", width: "2.8ch", textAlign: "right" }}>
        {pct}%
      </span>
    </div>
  );
}

export default function Dashboard() {
  const { tasks, workers, events, stats } = useQueueSimulation();
  const [tpHist, setTpHist] = useState(Array(20).fill(0));

  useEffect(() => {
    setTpHist(prev => [...prev.slice(1), stats.throughput]);
  }, [stats.throughput]);

  const pending = tasks.filter(t => t.status === "pending").length;
  const running = tasks.filter(t => t.status === "running").length;

  const statusColor = { pending: "#c9a227", running: "#5b9cf6", completed: "#4caf82", failed: "#c75d5d", idle: "#4a4f5a", busy: "#5b9cf6", saturated: "#c9a227" };
  const statusLabel = { pending: "PENDING", running: "RUNNING", completed: "DONE", failed: "FAILED", idle: "IDLE", busy: "BUSY", saturated: "SAT" };
  const evColor = { TASK_SUBMITTED: "#c9a227", TASK_ASSIGNED: "#5b9cf6", TASK_COMPLETED: "#4caf82", TASK_FAILED: "#c75d5d", WORKER_JOINED: "#4a4f5a", WORKER_LEFT: "#4a4f5a" };
  const evLabel = { TASK_SUBMITTED: "SUBMIT", TASK_ASSIGNED: "ASSIGN", TASK_COMPLETED: "DONE  ", TASK_FAILED: "FAIL  ", WORKER_JOINED: "JOIN  ", WORKER_LEFT: "LEAVE " };

  const mono = "IBM Plex Mono, monospace";
  const sans = "IBM Plex Sans, system-ui, sans-serif";
  const border = "1px solid #1e2025";

  return (
    <div style={{ background: "#0c0d0f", minHeight: "100vh", color: "#c9cbd0", fontFamily: sans, display: "flex", flexDirection: "column" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=IBM+Plex+Sans:wght@400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { width: 3px; background: transparent; }
        ::-webkit-scrollbar-thumb { background: #1e2025; }
        @keyframes rowflash { 0% { background: rgba(91,156,246,0.06); } 100% { background: transparent; } }
        .ev-new { animation: rowflash 0.5s ease; }
      `}</style>

      {/* Topbar */}
      <div style={{ height: 42, borderBottom: border, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 18px", background: "#0c0d0f", flexShrink: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          <span style={{ fontFamily: mono, fontSize: 12, fontWeight: 600, letterSpacing: "-0.01em" }}>taskqueue</span>
          <span style={{ color: "#1e2025" }}>|</span>
          <span style={{ fontFamily: mono, fontSize: 10, color: "#4a4f5a" }}>localhost:50051</span>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 7 }}>
          <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#4caf82", boxShadow: "0 0 5px #4caf82", display: "inline-block" }} />
          <span style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.06em" }}>CONNECTED</span>
        </div>
      </div>

      {/* Stats strip */}
      <div style={{ display: "flex", borderBottom: border, background: "#111316", flexShrink: 0 }}>
        {[
          { label: "pending",   val: pending,         color: "#c9a227" },
          { label: "running",   val: running,         color: "#5b9cf6" },
          { label: "completed", val: stats.completed, color: "#4caf82", sub: "total" },
          { label: "failed",    val: stats.failed,    color: "#c75d5d", sub: "total" },
          { label: "workers",   val: workers.length,  color: "#c9cbd0" },
        ].map((s, i, arr) => (
          <div key={s.label} style={{ padding: "11px 18px", borderRight: i < arr.length - 1 ? border : "none", minWidth: 100 }}>
            <div style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.07em", textTransform: "uppercase", marginBottom: 4 }}>{s.label}</div>
            <div style={{ fontFamily: mono, fontSize: 22, fontWeight: 700, color: s.color, lineHeight: 1 }}>{s.val}</div>
            {s.sub && <div style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", marginTop: 2 }}>{s.sub}</div>}
          </div>
        ))}
        <div style={{ padding: "11px 18px", display: "flex", flexDirection: "column", gap: 4, flex: 1 }}>
          <div style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.07em", textTransform: "uppercase" }}>throughput / min</div>
          <div style={{ display: "flex", alignItems: "flex-end", gap: 10 }}>
            <span style={{ fontFamily: mono, fontSize: 22, fontWeight: 700, color: "#4caf82", lineHeight: 1 }}>{stats.throughput}</span>
            <Sparkline values={tpHist} />
          </div>
        </div>
      </div>

      {/* Main grid */}
      <div style={{ flex: 1, display: "grid", gridTemplateColumns: "1fr 240px", overflow: "hidden" }}>

        {/* Left column */}
        <div style={{ display: "flex", flexDirection: "column", borderRight: border, overflow: "hidden" }}>

          {/* Workers */}
          <div style={{ borderBottom: border, flexShrink: 0 }}>
            <div style={{ padding: "5px 18px", background: "#111316", borderBottom: border }}>
              <span style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.07em", textTransform: "uppercase" }}>workers</span>
            </div>
            <div style={{ display: "flex" }}>
              {workers.map((w, i) => {
                const pct  = Math.round((w.load / w.capacity) * 100);
                const stat = w.load === 0 ? "idle" : w.load >= w.capacity ? "saturated" : "busy";
                return (
                  <div key={w.id} style={{ flex: 1, padding: "10px 18px", borderRight: i < workers.length - 1 ? border : "none" }}>
                    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
                      <span style={{ fontFamily: mono, fontSize: 11, color: "#c9cbd0", fontWeight: 500 }}>{w.id}</span>
                      <span style={{ fontFamily: mono, fontSize: 9, color: statusColor[stat], letterSpacing: "0.05em", fontWeight: 600 }}>{statusLabel[stat]}</span>
                    </div>
                    <div style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", marginBottom: 6 }}>{w.host}</div>
                    <Bar pct={pct} color={stat === "saturated" ? "#c9a227" : "#5b9cf6"} />
                    <div style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", marginTop: 4 }}>{w.load}/{w.capacity} slots</div>
                  </div>
                );
              })}
            </div>
          </div>

          {/* Task table */}
          <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
            <div style={{
              display: "grid",
              gridTemplateColumns: "5.5ch 1fr 60px 72px 1fr 36px",
              padding: "5px 18px",
              background: "#111316",
              borderBottom: border,
            }}>
              {["id", "type", "status", "worker", "progress", "pri"].map(h => (
                <span key={h} style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.06em", textTransform: "uppercase" }}>{h}</span>
              ))}
            </div>
            <div style={{ flex: 1, overflowY: "auto" }}>
              {tasks.slice(0, 100).map(t => {
                const hue = TYPE_HUE[t.type] ?? 200;
                return (
                  <div key={t.id} style={{
                    display: "grid",
                    gridTemplateColumns: "5.5ch 1fr 60px 72px 1fr 36px",
                    padding: "6px 18px",
                    borderBottom: border,
                    alignItems: "center",
                  }}>
                    <span style={{ fontFamily: mono, fontSize: 10, color: "#4a4f5a" }}>{t.id.slice(0, 5)}</span>
                    <span style={{
                      display: "inline-block",
                      padding: "1px 5px",
                      borderRadius: 2,
                      background: `hsla(${hue},60%,50%,0.08)`,
                      border: `1px solid hsla(${hue},60%,50%,0.2)`,
                      color: `hsl(${hue},65%,62%)`,
                      fontFamily: mono,
                      fontSize: 10,
                      whiteSpace: "nowrap",
                      width: "fit-content",
                    }}>{t.type}</span>
                    <span style={{ fontFamily: mono, fontSize: 9, color: statusColor[t.status] ?? "#4a4f5a", letterSpacing: "0.04em", fontWeight: 600 }}>
                      {statusLabel[t.status] ?? t.status.toUpperCase()}
                    </span>
                    <span style={{ fontFamily: mono, fontSize: 10, color: "#4a4f5a" }}>
                      {t.workerId ? t.workerId.replace("worker-", "w-") : "—"}
                    </span>
                    <div>
                      {t.status === "running" && <Bar pct={t.progress} />}
                      {(t.status === "completed" || t.status === "failed") && t.completedAt && (
                        <span style={{ fontFamily: mono, fontSize: 10, color: "#4a4f5a" }}>{fmtMs(t.completedAt - t.createdAt)}</span>
                      )}
                    </div>
                    <span style={{ fontFamily: mono, fontSize: 10, color: "#4a4f5a", textAlign: "right" }}>{t.priority}</span>
                  </div>
                );
              })}
              {tasks.length === 0 && (
                <div style={{ padding: "20px 18px", fontFamily: mono, fontSize: 11, color: "#4a4f5a" }}>waiting for tasks</div>
              )}
            </div>
          </div>
        </div>

        {/* Right: event log */}
        <div style={{ display: "flex", flexDirection: "column", overflow: "hidden" }}>
          <div style={{ padding: "5px 14px", background: "#111316", borderBottom: border, display: "flex", justifyContent: "space-between", alignItems: "center", flexShrink: 0 }}>
            <span style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.07em", textTransform: "uppercase" }}>events</span>
            <span style={{ fontFamily: mono, fontSize: 9, color: "#4caf82" }}>WatchEvents</span>
          </div>
          <div style={{ flex: 1, overflowY: "auto" }}>
            {events.map((ev, i) => (
              <div key={i} className={i === 0 ? "ev-new" : ""} style={{
                display: "grid",
                gridTemplateColumns: "4ch 6ch 1fr",
                gap: 6,
                padding: "5px 14px",
                borderBottom: border,
                alignItems: "baseline",
                opacity: Math.max(0.2, 1 - i * 0.025),
              }}>
                <span style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a" }}>{fmtAge(ev.ts)}</span>
                <span style={{ fontFamily: mono, fontSize: 9, color: evColor[ev.type] ?? "#4a4f5a", fontWeight: 600, letterSpacing: "0.03em" }}>
                  {(evLabel[ev.type] ?? ev.type).trim()}
                </span>
                <span style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                  {ev.taskId ? ev.taskId.slice(0, 5) : ""}
                  {ev.workerId ? ` ${ev.workerId.replace("worker-", "w-")}` : ""}
                  {ev.dur ? ` ${fmtMs(ev.dur)}` : ""}
                  {ev.taskType && !ev.taskId ? ev.taskType : ""}
                </span>
              </div>
            ))}
          </div>

          {/* RPC reference */}
          <div style={{ borderTop: border, padding: "10px 14px", background: "#111316", flexShrink: 0 }}>
            <div style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a", letterSpacing: "0.07em", textTransform: "uppercase", marginBottom: 8 }}>rpc</div>
            {[
              ["SubmitTask",     "unary"],
              ["WorkerStream",   "bidi"],
              ["ReportProgress", "unary"],
              ["WatchEvents",    "server"],
              ["GetStats",       "unary"],
            ].map(([name, kind]) => (
              <div key={name} style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                <span style={{ fontFamily: mono, fontSize: 9, color: "#c9cbd0" }}>{name}</span>
                <span style={{ fontFamily: mono, fontSize: 9, color: "#4a4f5a" }}>{kind}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
