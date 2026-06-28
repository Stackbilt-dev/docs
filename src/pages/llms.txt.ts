import type { APIRoute } from 'astro';
import { getCollection } from 'astro:content';
import { getNavigation } from '../lib/navigation';

export const GET: APIRoute = async ({ site }) => {
  const docs = await getCollection('docs');
  const { sections } = await getNavigation();
  const origin = site!.origin;

  // Sort docs by section order then page order for a logical reading sequence
  const sorted = docs
    .map((doc) => ({
      slug: doc.id.replace(/\.md$/, ''),
      title: doc.data.title,
      description: doc.data.description,
      section: doc.data.section,
      order: doc.data.order,
    }))
    .sort((a, b) => a.order - b.order);

  const lines: string[] = [
    `# Docs by Stackbilt`,
    ``,
    `> Developer documentation for the Stackbilt ecosystem: Charter CLI (open-source AI governance),`,
    `> AEGIS Core (persistent agent framework), audit-chain, evidence-core, worker-observability,`,
    `> and the Stackbilder commercial platform. All pages are available as Markdown alternates.`,
    ``,
    `## Site`,
    ``,
    `- [Docs Home](${origin}/): Landing page — redirects to Ecosystem overview`,
    `- [Sitemap](${origin}/sitemap-index.xml): XML sitemap index`,
    `- [Schema Map](${origin}/schemamap.xml): JSON-LD schema endpoint index`,
    ``,
  ];

  // Group by section
  for (const section of sections) {
    lines.push(`## ${section.label}`);
    lines.push(``);

    const sectionDocs = sorted.filter((d) => d.section === section.id);
    for (const doc of sectionDocs) {
      const desc = doc.description.length > 120
        ? doc.description.slice(0, 119) + '…'
        : doc.description;
      lines.push(`- [${doc.title}](${origin}/${doc.slug}/): ${desc}`);
      lines.push(`  - Markdown: ${origin}/${doc.slug}.md`);
      lines.push(`  - Schema: ${origin}/schema/${doc.slug}.json`);
    }
    lines.push(``);
  }

  lines.push(`## External`);
  lines.push(``);
  lines.push(`- [GitHub — Charter CLI](https://github.com/Stackbilt-dev/charter): Open-source CLI source`);
  lines.push(`- [npm — @stackbilt/cli](https://www.npmjs.com/package/@stackbilt/cli): Published package`);
  lines.push(`- [Stackbilder Platform](https://stackbilder.com): Commercial platform`);
  lines.push(``);

  return new Response(lines.join('\n'), {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
};
