/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        sb: {
          bg: '#050508',
          surface: '#0a0e16',
          hover: '#0f1420',
          border: '#1a2030',
          'text-1': '#e6edf3',
          'text-2': '#b8c0cc',
          muted: '#5c6370',
          dim: '#353b47',
          faint: '#1c2028',
          amber: '#f5a623',
          green: '#2ea043',
          pink: '#f472b6',
          cyan: '#22d3ee',
          purple: '#c084fc',
        },
      },
      fontFamily: {
        terminal: ['"SF Mono"', '"Cascadia Code"', '"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'Menlo', 'Monaco', 'Consolas', 'monospace'],
        body: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
        heading: ['Inter', 'system-ui', '-apple-system', 'sans-serif'],
      },
    },
  },
  plugins: [],
};
