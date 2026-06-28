#!/usr/bin/env node
/**
 * IndexNow submission — production deploys only.
 *
 * Setup:
 *   1. Generate a key: https://www.bing.com/indexnow
 *   2. Create public/{key}.txt containing the key value
 *   3. Set INDEXNOW_KEY={key} in your Cloudflare Pages / CI environment
 *
 * This script reads URLs from the built sitemap and notifies Bing + Yandex.
 * It is a no-op if INDEXNOW_KEY is not set, so staging/local builds are safe.
 */
import { readFileSync } from 'fs';
import { existsSync } from 'fs';

const SITE_HOST = 'docs.stackbilder.com';
const SITE_ORIGIN = `https://${SITE_HOST}`;
const KEY = process.env.INDEXNOW_KEY;
const SITEMAP_PATH = './dist/sitemap-0.xml';
// When using chunks, the primary chunk is named 'docs' → sitemap-docs-0.xml
const SITEMAP_CHUNKS_PATH = './dist/sitemap-docs-0.xml';

if (!KEY) {
  console.log('[indexnow] INDEXNOW_KEY not set — skipping submission (safe for staging/local)');
  process.exit(0);
}

// Prefer the chunked sitemap; fall back to default
const sitemapPath = existsSync(SITEMAP_CHUNKS_PATH)
  ? SITEMAP_CHUNKS_PATH
  : existsSync(SITEMAP_PATH)
  ? SITEMAP_PATH
  : null;

if (!sitemapPath) {
  console.error('[indexnow] No sitemap found in dist/. Run `astro build` first.');
  process.exit(1);
}

const sitemap = readFileSync(sitemapPath, 'utf-8');
const urls = [...sitemap.matchAll(/<loc>(https?:\/\/[^<]+)<\/loc>/g)].map((m) => m[1]);

if (urls.length === 0) {
  console.warn('[indexnow] No URLs found in sitemap.');
  process.exit(0);
}

console.log(`[indexnow] Submitting ${urls.length} URLs to IndexNow...`);

const payload = {
  host: SITE_HOST,
  key: KEY,
  keyLocation: `${SITE_ORIGIN}/${KEY}.txt`,
  urlList: urls,
};

const endpoints = [
  'https://api.indexnow.org/indexnow',
  'https://www.bing.com/indexnow',
];

for (const endpoint of endpoints) {
  try {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
      body: JSON.stringify(payload),
    });
    console.log(`[indexnow] ${endpoint} → HTTP ${res.status}`);
  } catch (err) {
    console.error(`[indexnow] ${endpoint} failed:`, err.message);
  }
}
