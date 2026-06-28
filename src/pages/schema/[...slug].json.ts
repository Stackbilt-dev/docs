import type { APIRoute, GetStaticPaths } from 'astro';
import { getCollection } from 'astro:content';

export const getStaticPaths: GetStaticPaths = async () => {
  const docs = await getCollection('docs');
  return docs.map((doc) => ({
    params: { slug: doc.id.replace(/\.md$/, '') },
    props: { doc },
  }));
};

export const GET: APIRoute = ({ props, site }) => {
  const { doc } = props as Awaited<ReturnType<typeof getStaticPaths>>[number]['props'] & {
    doc: Awaited<ReturnType<typeof getCollection<'docs'>>>[number];
  };

  const origin = site!.origin;
  const slug = doc.id.replace(/\.md$/, '');
  const canonicalUrl = `${origin}/${slug}/`;
  const siteHref = site!.href;
  const description =
    doc.data.description.length > 160
      ? doc.data.description.slice(0, 159) + '…'
      : doc.data.description;

  const graph = {
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'WebSite',
        '@id': `${origin}/#website`,
        name: 'Docs by Stackbilt',
        url: siteHref,
        publisher: { '@id': 'https://stackbilder.com/#organization' },
      },
      {
        '@type': 'Organization',
        '@id': 'https://stackbilder.com/#organization',
        name: 'Stackbilt',
        url: 'https://stackbilder.com',
        sameAs: [
          'https://github.com/Stackbilt-dev',
          'https://www.npmjs.com/org/stackbilt',
        ],
        logo: {
          '@type': 'ImageObject',
          url: `${origin}/favicon.svg`,
          width: 48,
          height: 48,
        },
      },
      {
        '@type': 'Person',
        '@id': 'https://stackbilder.com/#author',
        name: 'Kurt Overmier',
        url: 'https://stackbilder.com',
        image: {
          '@type': 'ImageObject',
          '@id': 'https://stackbilder.com/#author-photo',
          url: `${origin}/author.jpg`,
          width: 400,
          height: 400,
          caption: 'Kurt Overmier',
        },
        sameAs: [
          'https://www.buymeacoffee.com/kurto',
        ],
      },
      {
        '@type': 'TechArticle',
        '@id': `${canonicalUrl}#article`,
        isPartOf: { '@id': `${origin}/#website` },
        headline: doc.data.title,
        description,
        url: canonicalUrl,
        author: { '@id': 'https://stackbilder.com/#author' },
        breadcrumb: { '@id': `${canonicalUrl}#breadcrumb` },
        publisher: { '@id': 'https://stackbilder.com/#organization' },
        inLanguage: 'en-US',
        encoding: {
          '@type': 'MediaObject',
          encodingFormat: 'text/markdown',
          contentUrl: `${origin}/${slug}.md`,
        },
        ...(doc.data.ogImage
          ? {
              image: {
                '@type': 'ImageObject',
                url: doc.data.ogImage,
                width: 1200,
                height: 630,
              },
            }
          : {}),
      },
      {
        '@type': 'BreadcrumbList',
        '@id': `${canonicalUrl}#breadcrumb`,
        itemListElement: [
          {
            '@type': 'ListItem',
            position: 1,
            item: { '@type': 'WebPage', '@id': siteHref, name: 'Docs', url: siteHref },
          },
          {
            '@type': 'ListItem',
            position: 2,
            item: {
              '@type': 'WebPage',
              '@id': canonicalUrl,
              name: doc.data.title,
              url: canonicalUrl,
            },
          },
        ],
      },
    ],
  };

  return new Response(JSON.stringify(graph, null, 2), {
    headers: {
      'Content-Type': 'application/ld+json; charset=utf-8',
      'Access-Control-Allow-Origin': '*',
    },
  });
};
