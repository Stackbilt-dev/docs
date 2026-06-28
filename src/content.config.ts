import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const docs = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/docs' }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    section: z.string(),
    order: z.number(),
    color: z.string(),
    tag: z.string(),
    // Wiki-as-SoT migration (Phase 2): optional metadata surfaced from
    // AEGIS wiki when the page is synced from there. Used to render a
    // "Verified <date>" stamp and a back-link to the wiki source.
    lastVerified: z.string().optional(),
    sourceSlug: z.string().optional(),
  }),
});

export const collections = { docs };
