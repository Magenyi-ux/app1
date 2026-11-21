import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json"}});
const env=(key:string)=>Deno.env.get(key)||"";
Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
  if(req.method!=="POST")return json({error:"Method not allowed"},405);
  const url=env("SUPABASE_URL"),anon=env("SUPABASE_ANON_KEY"),service=env("SUPABASE_SERVICE_ROLE_KEY");
  const pub=env("VAPID_PUBLIC_KEY"),priv=env("VAPID_PRIVATE_KEY"),subject=env("VAPID_SUBJECT")||"mailto:founder@spherelearn.name.ng";
  if(!url||!anon||!service)return json({error:"Push service is not configured on the server."},503);
  const token=(req.headers.get("Authorization")||"").replace(/^Bearer\s+/i,"");
  if(!token)return json({error:"Sign in required."},401);
  const authClient=createClient(url,anon,{global:{headers:{Authorization:"Bearer "+token}},auth:{persistSession:false}});
  const {data:{user},error:authError}=await authClient.auth.getUser(token);
  if(authError||!user)return json({error:"Your session is invalid. Sign in again."},401);
  let input:any;try{input=await req.json()}catch{return json({error:"Invalid request body."},400)}
  if(input.action==="public-key"){
    if(!pub)return json({error:"Push notifications are not configured yet."},503);
    return json({publicKey:pub});
  }
  if(!pub||!priv)return json({error:"Push notifications are not configured yet. VAPID keys are missing."},503);
  webpush.setVapidDetails(subject,pub,priv);
  const admin=createClient(url,service,{auth:{persistSession:false}});
  if(input.action==="subscribe"){
    const s=input.subscription;
    if(!s||typeof s.endpoint!=="string"||!s.endpoint.startsWith("https://")||!s.keys?.p256dh||!s.keys?.auth)return json({error:"Invalid push subscription."},400);
    const {error}=await admin.from("push_subscriptions").upsert({user_id:user.id,endpoint:s.endpoint,p256dh:s.keys.p256dh,auth:s.keys.auth,updated_at:new Date().toISOString()},{onConflict:"endpoint"});
    if(error)return json({error:"Could not save this device subscription."},500);
    return json({ok:true});
  }
  if(input.action==="test"){
    const {data:subs,error}=await admin.from("push_subscriptions").select("id,endpoint,p256dh,auth").eq("user_id",user.id);
    if(error)return json({error:"Could not load your device subscriptions."},500);
    if(!subs?.length)return json({error:"This device is not subscribed yet."},400);
    const payload=JSON.stringify({title:"Thought & Feelings",body:"Notifications are working on this device.",url:"/",tag:"tf-test"});
    const results=await Promise.all(subs.map(async(s:any)=>{
      try{await webpush.sendNotification({endpoint:s.endpoint,keys:{p256dh:s.p256dh,auth:s.auth}},payload);return {id:s.id,ok:true}}
      catch(error:any){if(error?.statusCode===404||error?.statusCode===410)await admin.from("push_subscriptions").delete().eq("id",s.id);return {id:s.id,ok:false}}
    }));
    return results.some(r=>r.ok)?json({ok:true}):json({error:"Delivery failed. Check VAPID configuration and browser subscription."},502);
  }
  return json({error:"Unsupported action."},400);
});
