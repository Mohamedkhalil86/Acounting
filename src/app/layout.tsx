import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'حسابي — دفتر حساباتك', description: 'دفتر حسابات العملاء والديون' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="ar" dir="rtl"><body>{children}</body></html>; }
