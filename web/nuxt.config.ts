export default defineNuxtConfig({
  compatibilityDate: '2026-07-10',
  devtools: { enabled: false },
  css: ['~/assets/css/main.css'],
  routeRules: {
    '/api/github': { cache: { maxAge: 60 * 60 } },
  },
  runtimeConfig: {
    public: {
      siteUrl: '',
    },
  },
  app: {
    head: {
      htmlAttrs: { lang: 'zh-CN' },
      meta: [
        { name: 'theme-color', content: '#07110f' },
        { name: 'color-scheme', content: 'dark' },
      ],
      link: [
        { rel: 'icon', type: 'image/png', href: '/app-icon.png' },
      ],
    },
  },
})
