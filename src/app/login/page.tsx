'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { ArrowLeft, BookOpen, Eye, EyeOff, LoaderCircle, LockKeyhole, Mail } from 'lucide-react';

export default function LoginPage() {
  const supabase = createClient();
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [redirectTo, setRedirectTo] = useState('/dashboard');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setRedirectTo(params.get('next') || '/dashboard');
  }, []);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError('');
    setBusy(true);
    try {
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) throw authError;
      router.push(redirectTo);
      router.refresh();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'تعذر تسجيل الدخول. حاول مرة أخرى.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="min-h-screen bg-white lg:grid lg:grid-cols-2" dir="rtl">
      <section className="relative hidden flex-col justify-between overflow-hidden bg-[#153f31] p-14 text-white lg:flex">
        <div className="absolute -bottom-40 -left-28 h-[520px] w-[520px] rounded-full border border-white/10" />
        <div className="absolute -bottom-24 -left-12 h-[360px] w-[360px] rounded-full border border-white/10" />
        <Link href="/" className="relative flex items-center gap-3">
          <span className="grid h-11 w-11 place-items-center rounded-2xl bg-white/10"><BookOpen /></span>
          <span className="text-2xl font-extrabold">حسابي</span>
        </Link>
        <div className="relative max-w-lg">
          <p className="mb-4 font-bold text-emerald-200">دفتر حساباتك، ببساطة</p>
          <h1 className="text-5xl font-extrabold leading-[1.45]">كل حساباتك<br />في مكان واحد.</h1>
          <p className="mt-6 text-lg leading-8 text-white/65">تابع أرصدة عملائك، سجّل المعاملات، واعرف موقفك المالي في لحظة.</p>
          <div className="mt-10 rounded-3xl border border-white/10 bg-white/10 p-6">
            <div className="flex justify-between text-sm"><span>إجمالي المستحقات</span><span>هذا الشهر</span></div>
            <div className="mt-3 text-3xl font-bold tabular-nums">١٢٬٥٠٠ ج.م</div>
            <div className="mt-5 h-2 rounded-full bg-white/15"><div className="h-full w-2/3 rounded-full bg-emerald-300" /></div>
          </div>
        </div>
        <p className="relative text-sm text-white/40">حسابات مرتبة. قرارات أوضح.</p>
      </section>

      <section className="flex items-center justify-center px-6 py-12">
        <div className="w-full max-w-md">
          <Link href="/" className="mb-12 flex items-center gap-2 text-xl font-extrabold text-forest lg:hidden"><BookOpen /> حسابي</Link>
          <div className="mb-9">
            <h2 className="text-3xl font-extrabold">تسجيل الدخول</h2>
            <p className="mt-2 text-gray-500">أدخل بيانات حساب المسؤول للمتابعة.</p>
          </div>
          {error && <div role="alert" className="mb-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>}
          <form onSubmit={submit} className="space-y-5">
            <label className="block">
              <span className="text-sm font-bold">البريد الإلكتروني</span>
              <span className="mt-2 flex items-center rounded-xl border border-gray-200 px-3 focus-within:border-forest">
                <Mail size={18} className="text-gray-400" />
                <input required autoComplete="username" type="email" value={email} onChange={event => setEmail(event.target.value)} className="w-full p-3 outline-none" placeholder="name@example.com" dir="ltr" />
              </span>
            </label>
            <div className="block">
              <label htmlFor="login-password" className="text-sm font-bold">كلمة المرور</label>
              <span className="mt-2 flex items-center rounded-xl border border-gray-200 px-3 focus-within:border-forest">
                <LockKeyhole size={18} className="text-gray-400" />
                <input id="login-password" required autoComplete="current-password" type={showPassword ? 'text' : 'password'} value={password} onChange={event => setPassword(event.target.value)} className="w-full p-3 outline-none" placeholder="كلمة المرور" dir="ltr" />
                <button type="button" onClick={() => setShowPassword(visible => !visible)} aria-label={showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور'} aria-pressed={showPassword} className="rounded-lg p-2 text-gray-500 hover:bg-gray-100">
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </span>
            </div>
            <button disabled={busy} className="flex w-full items-center justify-center gap-2 rounded-xl bg-forest py-3.5 font-bold text-white hover:bg-[#10513a] disabled:opacity-60">
              {busy && <LoaderCircle className="animate-spin" size={18} />}
              تسجيل الدخول
              {!busy && <ArrowLeft size={17} />}
            </button>
          </form>
        </div>
      </section>
    </main>
  );
}
