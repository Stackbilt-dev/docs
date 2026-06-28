import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

const docs = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/docs' }),
  schema: z.object({
    // SEO: title must be 5–120 chars; keep primary keyword early
    title: z.string().min(5, 'Title too short (min 5 chars)').max(120, 'Title too long (max 120 chars)'),
    // SEO: description required — used for meta description (component trims to 160)
    description: z.string().min(10, 'Description too short (min 10 chars)'),
    section: z.string(),
    order: z.number(),
    color: z.string(),
    tag: z.string(),
    // Optional hero image URL for og:image override
    ogImage: z.string().url().optional(),
    // Wiki-as-SoT migration (Phase 2): optional metadata surfaced from
    // AEGIS wiki when the page is synced from there. Used to render a
    // "Verified <date>" stamp and a back-link to the wiki source.
    lastVerified: z.string().optional(),
    sourceSlug: z.string().optional(),
  }),
});

export const collections = { docs };
