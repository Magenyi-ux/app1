(function(){
  "use strict";
  const FUNCTION_NAME="push-notifications";
  function context(){try{return typeof window.tfNotificationsContext==="function"?window.tfNotificationsContext():{}}catch(_){return {}}}
  function currentUser(){return context().currentUser||null}
  function client(){return context().supabaseClient||null}
  function supabaseUrl(){const sb=client();return sb&&sb.supabaseUrl||""}
  function byId(id){return document.getElementById(id)}
  function announce(message){if(typeof window.toast==="function")window.toast(message);else alert(message)}
  function b64ToBytes(value){const padded=value+"=".repeat((4-value.length%4)%4);const raw=atob(padded.replace(/-/g,"+").replace(/_/g,"/"));return Uint8Array.from(raw,c=>c.charCodeAt(0))}
  async function callFunction(action,extra){
    const sb=client(), user=currentUser();
    if(!sb||!user)throw new Error("Sign in to manage notifications.");
    const {data:{session}}=await sb.auth.getSession();
    if(!session)throw new Error("Your session has expired. Sign in again.");
    const response=await fetch(supabaseUrl()+"/functions/v1/"+FUNCTION_NAME,{
      method:"POST",headers:{"Content-Type":"application/json","Authorization":"Bearer "+session.access_token,"apikey":sb.supabaseKey||""},
      body:JSON.stringify({action,...(extra||{})})
    });
    const data=await response.json().catch(()=>({}));
    if(!response.ok)throw new Error(data.error||"Notification service is not configured yet.");
    return data;
  }
  function mount(){
    const host=byId("profileDetails")||byId("profile");
    if(!host||byId("tfPushCard"))return;
    const card=document.createElement("section");card.id="tfPushCard";card.className="card";card.style.marginTop="16px";
    card.innerHTML='<div class="head"><div><h2>Notifications outside the app</h2><p class="sub">Get a device notification when Thought &amp; Feelings sends you an update.</p></div></div><p id="tfPushStatus" class="hint" role="status">Checking this device…</p><div class="row"><button id="tfEnablePush" class="btn primary" type="button">Enable notifications</button><button id="tfTestPush" class="btn secondary" type="button" hidden>Send test notification</button></div><p class="hint" style="margin-top:12px">Optional. Your browser asks for permission first. Journal entry text is never included in device notification previews.</p>';
    host.appendChild(card);
    refresh();
    byId("tfEnablePush").addEventListener("click",enable);
    byId("tfTestPush").addEventListener("click",testPush);
  }
  async function refresh(){
    const status=byId("tfPushStatus"),enable=byId("tfEnablePush"),test=byId("tfTestPush");
    if(!status)return;
    if(!("serviceWorker" in navigator)||!("PushManager" in window)||!("Notification" in window)){status.textContent="Push notifications are not supported in this browser. Try installing the PWA or use a supported browser.";enable.disabled=true;return}
    if(Notification.permission==="denied"){status.textContent="Notifications are blocked in browser settings. Change the site permission to enable them.";enable.disabled=true;return}
    try{const reg=await navigator.serviceWorker.ready;const sub=await reg.pushManager.getSubscription();if(sub){status.textContent="This device is subscribed to notifications.";enable.textContent="Refresh subscription";test.hidden=false}else{status.textContent="Notifications are off on this device.";enable.textContent="Enable notifications";test.hidden=true}}catch(_){status.textContent="Notifications are not available yet. Open the app online and try again."}
  }
  async function enable(){
    const button=byId("tfEnablePush"),status=byId("tfPushStatus");button.disabled=true;status.textContent="Setting up notifications…";
    try{
      const config=await callFunction("public-key");
      if(!config.publicKey)throw new Error("Push service is not configured yet. The site administrator must add the VAPID keys.");
      const permission=await Notification.requestPermission();
      if(permission!=="granted")throw new Error("Notification permission was not granted.");
      const reg=await navigator.serviceWorker.ready;
      const subscription=await reg.pushManager.subscribe({userVisibleOnly:true,applicationServerKey:b64ToBytes(config.publicKey)});
      await callFunction("subscribe",{subscription:subscription.toJSON()});
      status.textContent="Notifications are enabled on this device.";
      byId("tfTestPush").hidden=false;button.textContent="Refresh subscription";
      announce("Notifications enabled on this device.");
    }catch(error){status.textContent=error.message||"Could not enable notifications.";announce(status.textContent)}
    finally{button.disabled=false}
  }
  async function testPush(){
    const button=byId("tfTestPush"),status=byId("tfPushStatus");button.disabled=true;
    try{await callFunction("test");status.textContent="Test notification sent. It may take a moment to appear.";announce("Test notification sent.")}catch(error){status.textContent=error.message||"Could not send a test notification.";announce(status.textContent)}
    finally{button.disabled=false}
  }
  document.addEventListener("DOMContentLoaded",mount);
  window.addEventListener("load",mount);
  window.addEventListener("tf:profile-ready",mount);
})();
