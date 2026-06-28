import type { APIRoute, GetStaticPaths } from 'astro';
import { getCollection } from 'astro:content';
import { readFileSync } from 'fs';

export const getStaticPaths: GetStaticPaths = async () => {
  const docs = await getCollection('docs');
  return docs.map((doc) => ({
    params: { slug: doc.id.replace(/\.md$/, '') },
    props: { doc },
  }));
};

export const GET: APIRoute = ({ props }) => {
  const { doc } = props as Awaited<ReturnType<typeof getStaticPaths>>[number]['props'] & {
    doc: Awaited<ReturnType<typeof getCollection<'docs'>>>[number];
  };

  // Use body from content layer; fall back to reading file directly if unavailable
  let content: string;
  if (doc.body) {
    content = doc.body;
  } else if (doc.filePath) {
    content = readFileSync(doc.filePath, 'utf-8');
  } else {
    content = '';
  }

  return new Response(content, {
    headers: { 'Content-Type': 'text/markdown; charset=utf-8' },
  });
};
