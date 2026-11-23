"use client";
import { useEffect, useState } from "react";
import Link from "next/link";
import { LogOut, ShieldCheck } from "lucide-react";
import Dashboard from "@/components/dashboard";
import { createClient } from "@/lib/supabase";
import { DEMO_SESSION_KEY } from "@/lib/demo-auth";

export default function StaffGate(){const [state,setState]=useState<"checking"|"demo"|"admin"|"denied">("checking");const [sb,setSb]=useState<ReturnType<typeof createClient>>(null);
 useEffect(()=>{const client=createClient();setSb(client);if(!client){try{const session=JSON.parse(localStorage.getItem(DEMO_SESSION_KEY)||"null");if(session?.role==="admin"){setState("demo");return;}}catch{/* malformed demo session */}location.replace("/login?mode=admin");return;}let live=true;client.auth.getUser().then(async({data,error})=>{if(!live)return;if(error||!data.user){location.replace("/login?mode=admin");return;}const {data:profile}=await client.from("profiles").select("role,active").eq("id",data.user.id).maybeSingle();if(!live)return;if(profile?.active&&profile.role==="admin")setState("admin");else{await client.auth.signOut();setState("denied");}}).catch(()=>{if(live)location.replace("/login?mode=admin")});return()=>{live=false}},[]);
 if(state==="checking")return <div className="gate-loading"><ShieldCheck size={18}/> Verifying secure workspace access…</div>;
 if(state==="denied")return <div className="gate-loading"><b>Admin access required.</b><Link href="/login?mode=admin">Sign in with an administrator account</Link></div>;
 return <><Dashboard/>{(state==="admin"||state==="demo")&&<button className="secure-signout" onClick={async()=>{if(state==="admin")await sb?.auth.signOut();else localStorage.removeItem(DEMO_SESSION_KEY);location.assign("/login?mode=admin")}}><ShieldCheck size={14}/>{state==="demo"?"Demo admin session":"Admin session"}<LogOut size={14}/></button>}</>;
}
