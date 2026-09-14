import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://meowmin.taucity.xyz',
  trailingSlash: 'ignore',
  integrations: [
    // Internal reference pages stay out of the sitemap (they're also
    // noindex + unlinked): max-welcome is a widget mock, not content.
    sitemap({ filter: (page) => !page.includes('max-welcome') }),
  ],
  vite: {
    plugins: [tailwindcss()],
  },
});
