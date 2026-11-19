import type { Config } from 'tailwindcss';
const config: Config = { content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'], theme: { extend: { fontFamily: { sans: ['var(--font-cairo)', 'sans-serif'] }, colors: { ink: '#16251f', paper: '#f6f7f4', forest: '#17664b', mint: '#dff4e8', coral: '#dc6d4d' }, boxShadow: { card: '0 8px 28px rgba(20,45,34,.06)' } } }, plugins: [] };
export default config;
