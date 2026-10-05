<script setup>
import { v1 as uuidv1, v4 as uuidv4 } from 'uuid'

const version = ref('v4')
const count = ref(5)
const uuids = ref([])
const copied = ref(null)
const uppercase = ref(false)

const versionOptions = [
  { label: 'v1 — timestamp', value: 'v1', desc: 'Time-based, includes MAC address component' },
  { label: 'v4 — random', value: 'v4', desc: 'Cryptographically random, most widely used' },
]

function generate() {
  const gen = version.value === 'v1' ? uuidv1 : uuidv4
  uuids.value = Array.from({ length: count.value }, () => {
    const id = gen()
    return uppercase.value ? id.toUpperCase() : id
  })
}

async function copy(id) {
  await navigator.clipboard.writeText(id)
  copied.value = id
  setTimeout(() => (copied.value = null), 1500)
}

async function copyAll() {
  await navigator.clipboard.writeText(uuids.value.join('\n'))
  copied.value = '__all__'
  setTimeout(() => (copied.value = null), 1500)
}

// Generate on mount
generate()
</script>

<template>
  <main class="page">
    <!-- Header -->
    <header class="header">
      <div class="logo">
        UUID-<span class="logo-accent">GEN</span>
        <!-- <span class="logo-bracket">[</span> -->
        <!-- UUID -->
        <!-- <span class="logo-accent">GEN</span> -->
        <!-- <span class="logo-bracket">]</span> -->
      </div>
      <p class="tagline">Universally Unique Identifier</p>
    </header>

    <!-- Controls -->
    <section class="controls">
      <!-- Version selector -->
      <div class="control-group">
        <label class="control-label">VERSION</label>
        <div class="version-tabs">
          <button
            v-for="opt in versionOptions"
            :key="opt.value"
            class="version-tab"
            :class="{ active: version === opt.value }"
            @click="version = opt.value"
          >
            {{ opt.label }}
          </button>
        </div>
        <p class="version-desc">
          {{ versionOptions.find(o => o.value === version)?.desc }}
        </p>
      </div>

      <!-- Count slider -->
      <div class="control-group">
        <label class="control-label">COUNT — <span class="accent">{{ count }}</span></label>
        <input
          v-model.number="count"
          type="range"
          min="1"
          max="20"
          class="slider"
        />
      </div>

      <!-- Uppercase toggle -->
      <div class="control-group inline">
        <label class="control-label">UPPERCASE</label>
        <button
          class="toggle"
          :class="{ active: uppercase }"
          @click="uppercase = !uppercase"
        >
          <span class="toggle-knob" />
        </button>
      </div>

      <!-- Generate button -->
      <button class="btn-generate" @click="generate">
        <span>GENERATE</span>
        <span class="btn-arrow">→</span>
      </button>
    </section>

    <!-- Output -->
    <section v-if="uuids.length" class="output">
      <div class="output-header">
        <span class="output-title">{{ uuids.length }} UUID{{ uuids.length > 1 ? 'S' : '' }}</span>
        <button class="btn-copy-all" @click="copyAll">
          {{ copied === '__all__' ? '✓ Copied all' : 'Copy all' }}
        </button>
      </div>

      <ul class="uuid-list">
        <li
          v-for="id in uuids"
          :key="id"
          class="uuid-item"
          @click="copy(id)"
        >
          <span class="uuid-text">{{ id }}</span>
          <span class="uuid-copy-hint">
            {{ copied === id ? '✓' : 'copy' }}
          </span>
        </li>
      </ul>
    </section>

    <footer class="footer">
      Built with Nuxt 3 + uuid
    </footer>
  </main>
</template>

<style scoped>
.page {
  min-height: 100vh;
  max-width: 760px;
  margin: 0 auto;
  padding: 3rem 2rem 2rem;
  display: flex;
  flex-direction: column;
  gap: 3rem;
}

/* Header */
.header {
  text-align: center;
}
.logo {
  font-family: var(--font-display);
  font-size: clamp(2.5rem, 8vw, 5rem);
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1;
}
.logo-bracket { color: var(--muted); }
.logo-accent { color: var(--accent); }
.tagline {
  margin-top: 0.75rem;
  color: var(--muted);
  font-size: 0.9rem;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

/* Controls */
.controls {
  display: flex;
  flex-direction: column;
  gap: 1.75rem;
  border: 1px solid var(--border);
  background: var(--surface);
  padding: 2rem;
  border-radius: 2px;
}

.control-group {
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}
.control-group.inline {
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
}
.control-label {
  font-size: 0.7rem;
  letter-spacing: 0.18em;
  color: var(--muted);
  font-weight: 700;
}
.accent { color: var(--accent); }

/* Version tabs */
.version-tabs {
  display: flex;
  gap: 0;
  border: 1px solid var(--border);
  border-radius: 2px;
  overflow: hidden;
}
.version-tab {
  flex: 1;
  padding: 0.65rem 1rem;
  background: transparent;
  border: none;
  border-right: 1px solid var(--border);
  color: var(--muted);
  font-family: var(--font-mono);
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.15s;
}
.version-tab:last-child { border-right: none; }
.version-tab:hover { background: var(--accent-dim); color: var(--text); }
.version-tab.active {
  background: var(--accent);
  color: #000;
  font-weight: 700;
}
.version-desc {
  font-size: 0.78rem;
  color: var(--muted);
  font-style: italic;
}

/* Slider */
.slider {
  -webkit-appearance: none;
  width: 100%;
  height: 2px;
  background: var(--border);
  outline: none;
  cursor: pointer;
}
.slider::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 18px;
  height: 18px;
  background: var(--accent);
  border-radius: 50%;
  cursor: pointer;
  transition: transform 0.1s;
}
.slider::-webkit-slider-thumb:hover { transform: scale(1.3); }

/* Toggle */
.toggle {
  width: 46px;
  height: 24px;
  background: var(--border);
  border: none;
  border-radius: 12px;
  cursor: pointer;
  position: relative;
  transition: background 0.2s;
  flex-shrink: 0;
}
.toggle.active { background: var(--accent); }
.toggle-knob {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 18px;
  height: 18px;
  background: #fff;
  border-radius: 50%;
  transition: transform 0.2s;
}
.toggle.active .toggle-knob { transform: translateX(22px); }

/* Generate button */
.btn-generate {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 1rem 2rem;
  background: var(--accent);
  color: #000;
  border: none;
  font-family: var(--font-display);
  font-size: 1rem;
  font-weight: 800;
  letter-spacing: 0.1em;
  cursor: pointer;
  border-radius: 2px;
  transition: opacity 0.15s, transform 0.1s;
  align-self: flex-start;
  min-width: 200px;
}
.btn-generate:hover { opacity: 0.88; }
.btn-generate:active { transform: scale(0.98); }
.btn-arrow { font-size: 1.2rem; }

/* Output */
.output {
  display: flex;
  flex-direction: column;
  gap: 0;
  border: 1px solid var(--border);
  border-radius: 2px;
  overflow: hidden;
}
.output-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1.25rem;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
}
.output-title {
  font-size: 0.7rem;
  letter-spacing: 0.18em;
  color: var(--muted);
  font-weight: 700;
}
.btn-copy-all {
  font-family: var(--font-mono);
  font-size: 0.75rem;
  color: var(--accent);
  background: transparent;
  border: 1px solid var(--accent-dim);
  padding: 0.3rem 0.75rem;
  border-radius: 2px;
  cursor: pointer;
  transition: background 0.15s;
}
.btn-copy-all:hover { background: var(--accent-dim); }

/* UUID list */
.uuid-list {
  list-style: none;
}
.uuid-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.85rem 1.25rem;
  border-bottom: 1px solid var(--border);
  cursor: pointer;
  transition: background 0.1s;
  gap: 1rem;
}
.uuid-item:last-child { border-bottom: none; }
.uuid-item:hover {
  background: var(--accent-dim);
}
.uuid-text {
  font-family: var(--font-mono);
  font-size: 0.88rem;
  color: var(--text);
  word-break: break-all;
  flex: 1;
}
.uuid-copy-hint {
  font-size: 0.7rem;
  color: var(--muted);
  letter-spacing: 0.1em;
  text-transform: uppercase;
  flex-shrink: 0;
  min-width: 30px;
  text-align: right;
  transition: color 0.15s;
}
.uuid-item:hover .uuid-copy-hint { color: var(--accent); }

/* Footer */
.footer {
  text-align: center;
  color: var(--muted);
  font-size: 0.75rem;
  letter-spacing: 0.1em;
  padding-top: 1rem;
  border-top: 1px solid var(--border);
}
</style>
