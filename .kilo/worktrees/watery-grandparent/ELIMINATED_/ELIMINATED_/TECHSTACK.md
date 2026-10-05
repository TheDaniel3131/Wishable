Tech Stack for ELIMINATED_
Since we built this as a high-performance, single-file browser application, the tech stack is completely modern and relies on zero external heavy libraries (no Redux, no heavy animation frameworks).

Here is the exact stack:

Framework: Vue 3 (using the modern Composition API <script setup>).

Language: TypeScript (for strict prop typing and variable safety).

Styling: Tailwind CSS v4 (using the new Vite plugin engine for instantaneous utility class generation without PostCSS config files).

Build Tool: Vite (for sub-second hot module replacement and compiling).

Audio Engine: Web Audio API (Native browser API. Instead of using .mp3 files, we used mathematical oscillators to generatively synthesize the 8-bit sound effects directly in the user's processor).

Database/Cache: Web Storage API (localStorage) (Native browser API used to persist the task list across browser sessions without needing a backend server).

Animations: Native CSS3 Keyframes (Hardware-accelerated @keyframes for the screen shake, pop-ins, and neon pulsing).