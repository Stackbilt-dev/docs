import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://docs.stackbilt.dev',
  output: 'static',
  integrations: [
    mdx(),
    tailwind(),
    sitemap(),
  ],
  markdown: {
    shikiConfig: {
      theme: 'github-dark-default',
    },
  },
});
