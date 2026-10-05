export default defineNuxtConfig({
  devtools: { enabled: true },

  app: {
    head: {
      title: 'UUID Generator',
      meta: [
        { name: 'description', content: 'Generate UUIDs instantly — v1, v4, v5, and more.' }
      ],
      link: [
        { rel: 'preconnect', href: 'https://fonts.googleapis.com' },
        { rel: 'preconnect', href: 'https://fonts.gstatic.com', crossorigin: '' },
        {
          rel: 'stylesheet',
          href: 'https://fonts.googleapis.com/css2?family=Syne+Mono&family=Syne:wght@400;700;800&display=swap'
        }
      ]
    }
  },

  css: ['~/assets/css/main.css']
})
