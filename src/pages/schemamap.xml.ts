import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';

export const GET: APIRoute = async ({ site }) => {
  const docs = await getCollection('docs');
  const origin = site!.origin;

  const entries = docs
    .map((doc) => doc.id.replace(/\.md$/, ''))
    .sort()
    .map(
      (slug) =>
        `  <schemamap>\n    <loc>${origin}/schema/${slug}.json</loc>\n    <type>TechArticle</type>\n  </schemamap>`
    )
    .join('\n');

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<schemamapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${entries}
</schemamapindex>`;

  return new Response(xml, {
    headers: { 'Content-Type': 'application/xml; charset=utf-8' },
  });
};
