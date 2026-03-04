import { getCollection } from 'astro:content';

export interface NavItem {
  slug: string;
  title: string;
  section: string;
  order: number;
  color: string;
  tag: string;
}

export interface NavSection {
  id: string;
  label: string;
  color: string;
  items: NavItem[];
}

export const SECTION_META: Record<string, { label: string; color: string; order: number }> = {
  charter: { label: 'Charter CLI', color: '#2ea043', order: 1 },
  platform: { label: 'Platform', color: '#f472b6', order: 2 },
  ecosystem: { label: 'Ecosystem', color: '#c084fc', order: 3 },
};

export async function getNavigation(): Promise<{
  sections: NavSection[];
  flat: NavItem[];
}> {
  const docs = await getCollection('docs');
  const flat: NavItem[] = docs
    .map((doc) => ({
      slug: doc.id.replace(/\.md$/, ''),
      title: doc.data.title,
      section: doc.data.section,
      order: doc.data.order,
      color: doc.data.color,
      tag: doc.data.tag,
    }))
    .sort((a, b) => a.order - b.order);

  const sectionMap = new Map<string, NavItem[]>();
  for (const item of flat) {
    if (!sectionMap.has(item.section)) sectionMap.set(item.section, []);
    sectionMap.get(item.section)!.push(item);
  }

  const sections: NavSection[] = Array.from(sectionMap.entries())
    .map(([id, items]) => ({
      id,
      label: SECTION_META[id]?.label ?? id,
      color: SECTION_META[id]?.color ?? '#5c6370',
      items,
    }))
    .sort((a, b) => (SECTION_META[a.id]?.order ?? 99) - (SECTION_META[b.id]?.order ?? 99));

  return { sections, flat };
}
