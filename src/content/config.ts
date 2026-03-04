import { defineCollection, z } from 'astro:content';

const docs = defineCollection({
  type: 'content',
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    section: z.string(),
    order: z.number(),
    color: z.string(),
    tag: z.string(),
  }),
});

export const collections = { docs };
