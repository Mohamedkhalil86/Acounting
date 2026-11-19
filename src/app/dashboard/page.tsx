import Ledger from '@/components/ledger';
import { createClient } from '@/lib/supabase/server';
import { redirect } from 'next/navigation';
export default async function DashboardPage(){
 const supabase=await createClient();
 const {data:{user},error:authError}=await supabase.auth.getUser();
 if(authError)console.error('[Dashboard] Supabase auth lookup failed',authError);
 if(!user)redirect('/login');
 const [clientResult,profileResult]=await Promise.all([
  supabase.from('clients').select('*').order('updated_at',{ascending:false}),
  supabase.from('profiles').select('full_name').eq('id',user.id).maybeSingle()
 ]);
 if(clientResult.error)console.error('[Dashboard] Initial client query failed',clientResult.error);
 if(profileResult.error)console.error('[Dashboard] Initial profile query failed',profileResult.error);
 const initialError=clientResult.error?.message||profileResult.error?.message||'';
 return <Ledger initialClients={clientResult.data||[]} initialError={initialError} userName={profileResult.data?.full_name||user.email?.split('@')[0]||'حسابي'} email={user.email||''}/>;
}
