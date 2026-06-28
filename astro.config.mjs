import { defineConfig } from 'astro/config';
import mdx from '@astrojs/mdx';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';
import { execSync } from 'child_process';

/** Return the last git-commit ISO timestamp for a source file, or build time as fallback. */
function getGitLastmod(filePath) {
  try {
    const ts = execSync(`git log --format="%aI" -1 -- "${filePath}"`, {
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'ignore'],
    }).trim();
    return ts || new Date().toISOString();
  } catch {
    return new Date().toISOString();
  }
}

export default defineConfig({
  site: 'https://docs.stackbilder.com',
  output: 'static',
  integrations: [
    mdx(),
    tailwind(),
    sitemap({
      // Split into named chunks by content type — docs-0.xml, with room for future types
      chunks: {
        docs: (item) => {
          const pathname = new URL(item.url).pathname;
          // Exclude schema endpoints and raw file routes from the main sitemap
          if (pathname.startsWith('/schema/') || pathname.endsWith('.md') || pathname.endsWith('.json')) {
            return undefined;
          }
          return item;
        },
      },
      // Map git-commit timestamps to <lastmod>
      serialize(item) {
        const pathname = new URL(item.url).pathname;
        // Derive the source file slug from the URL path (strip leading/trailing slashes)
        const slug = pathname.replace(/^\/|\/$/g, '');
        const filePath = slug ? `src/content/docs/${slug}.md` : null;
        const lastmod = filePath ? getGitLastmod(filePath) : new Date().toISOString();
        return {
          ...item,
          lastmod,
          changefreq: slug ? 'weekly' : 'daily',
          priority: slug ? 0.8 : 1.0,
        };
      },
    }),
  ],
  markdown: {
    shikiConfig: {
      theme: 'github-dark-default',
    },
  },
});
