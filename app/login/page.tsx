"use client";
import { useState } from "react";
import Link from "next/link";
import { ArrowLeft, ArrowRight, KeyRound, LockKeyhole, Mail, UserRound } from "lucide-react";
import { createClient } from "@/lib/supabase";
import { DEMO_ADMIN, DEMO_CUSTOMER, DEMO_SESSION_KEY } from "@/lib/demo-auth";

type Mode="admin"|"customer";
export default function Login(){
 const [mode,setMode]=useState<Mode>("admin");const [identity,setIdentity]=useState("");const [password,setPassword]=useState("");const [error,setError]=useState("");const [busy,setBusy]=useState(false);
 async function submit(e:React.FormEvent){e.preventDefault();setError("");setBusy(true);
  const sb=createClient();
  if(!sb){
   const ok=mode==="admin"?identity.trim().toLowerCase()===DEMO_ADMIN.email&&password===DEMO_ADMIN.password:identity.trim().toUpperCase()===DEMO_CUSTOMER.id&&password===DEMO_CUSTOMER.password;
   if(!ok){setBusy(false);setError("Those demo sign-in details don’t match. Use the demo credentials shown below.");return;}
   try{localStorage.setItem(DEMO_SESSION_KEY,JSON.stringify({role:mode,name:mode==="admin"?"Demo Administrator":"Demo Customer",createdAt:new Date().toISOString()}));}catch{setBusy(false);setError("This browser is blocking local storage, so demo sign-in cannot be saved.");return;}
   location.assign(mode==="admin"?"/":"/portal");return;
  }
  try{
   // Customer IDs map to synthetic Supabase emails; real email addresses stay private.
   const normalized=identity.trim().toLowerCase().replace(/[^a-z0-9]/g,"");
   const email=mode==="customer"?`customer-${normalized}@accounts.topclasstrack.invalid`:identity.trim().toLowerCase();
   const {data,error:authError}=await sb.auth.signInWithPassword({email,password});
   if(authError||!data.user){setError("We couldn’t sign you in with those details. Check them and try again.");return;}
   const {data:profile,error:profileError}=await sb.from("profiles").select("role,active").eq("id",data.user.id).maybeSingle();
   const roleAllowed=!profileError&&profile?.active&&(mode==="admin"?profile.role==="admin":profile.role==="customer");
   if(!roleAllowed){await sb.auth.signOut();setError("This account does not have access to this sign-in. Contact the workshop administrator.");return;}
   location.assign(mode==="admin"?"/":"/portal");
  }catch{setError("The sign-in service could not be reached. Check your connection or Supabase setup and try again.");}
  finally{setBusy(false);}
 }
 return <main className="auth-shell"><div className="auth-brand"><div className="brand-mark"><span>TC</span><i/></div><div className="brand-copy"><strong>TOPCLASS<span>TRACK</span></strong><small>AUTO BODY · ZIMBABWE</small></div></div><div className="auth-card"><div className="auth-symbol"><KeyRound size={20}/></div><span className="modal-kicker">SECURE SIGN IN</span><h1>{mode==="admin"?"Admin workspace":"Your repair, in view."}</h1><p>{mode==="admin"?"Sign in to manage workshop operations and customer records.":"Sign in to see progress for vehicles linked to your customer account."}</p><div className="auth-tabs" role="tablist" aria-label="Choose sign-in type"><button type="button" role="tab" aria-selected={mode==="admin"} className={mode==="admin"?"selected":""} onClick={()=>{setMode("admin");setIdentity("");setPassword("");setError("")}}><LockKeyhole size={14}/> Admin</button><button type="button" role="tab" aria-selected={mode==="customer"} className={mode==="customer"?"selected":""} onClick={()=>{setMode("customer");setIdentity("");setPassword("");setError("")}}><UserRound size={14}/> Customer</button></div><form onSubmit={submit}><label>{mode==="admin"?"Admin email":"Customer ID"}<div className="auth-input">{mode==="admin"?<Mail size={15}/>:<UserRound size={15}/>}<input required type={mode==="admin"?"email":"text"} autoComplete={mode==="admin"?"username":"username"} value={identity} onChange={e=>setIdentity(e.target.value)} placeholder={mode==="admin"?DEMO_ADMIN.email:DEMO_CUSTOMER.id}/></div></label><label>Password<div className="auth-input"><KeyRound size={15}/><input required type="password" autoComplete="current-password" value={password} onChange={e=>setPassword(e.target.value)} placeholder="Enter your password"/></div></label><button className="primary-btn auth-submit" disabled={busy}>{busy?"Signing in securely…":mode==="admin"?"Sign in to admin workspace":"Sign in to customer portal"}<ArrowRight size={15}/></button></form>{error&&<div className="auth-error" role="alert">{error}</div>}<div className="demo-credentials"><b>LOCAL DEMO ACCOUNT</b><span>{mode==="admin"?`Email: ${DEMO_ADMIN.email}`:`Customer ID: ${DEMO_CUSTOMER.id}`}</span><span>Password: {mode==="admin"?DEMO_ADMIN.password:DEMO_CUSTOMER.password}</span><small>Demo-only credentials. Use separate accounts for real deployment.</small></div><div className="auth-privacy">{mode==="admin"?"Admin access is limited to accounts assigned the administrator role.":"Your customer ID is not a password. In production, customer records are isolated by authenticated account."}</div><Link href="/" className="auth-home"><ArrowLeft size={14}/> Back to workshop workspace</Link></div><div className="auth-footer">TOP CLASS AUTO BODY · HARARE, ZIMBABWE</div></main>
}
