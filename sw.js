const CACHE="thought-feelings-shell-v4";
const ASSETS=["/","/index.html","/manifest.webmanifest","/icon.svg","/push-notifications.js"];
self.addEventListener("install",e=>e.waitUntil(caches.open(CACHE).then(c=>c.addAll(ASSETS)).then(()=>self.skipWaiting())));
self.addEventListener("activate",e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener("fetch",e=>{if(e.request.method!=="GET")return;e.respondWith(caches.match(e.request).then(cached=>cached||fetch(e.request).then(response=>{if(response.ok){const copy=response.clone();caches.open(CACHE).then(c=>c.put(e.request,copy))}return response}).catch(()=>caches.match("/index.html"))))});
self.addEventListener("push",event=>{
  let payload={title:"Thought & Feelings",body:"You have a new update.",url:"/"};
  try{if(event.data)payload={...payload,...event.data.json()}}catch(_){}
  event.waitUntil(self.registration.showNotification(payload.title||"Thought & Feelings",{
    body:payload.body||"You have a new update.",
    icon:"/icon.svg",badge:"/icon.svg",tag:payload.tag||"tf-update",
    data:{url:typeof payload.url==="string"&&payload.url.startsWith("/")?payload.url:"/"}
  }));
});
self.addEventListener("notificationclick",event=>{
  event.notification.close();
  const path=event.notification.data&&event.notification.data.url||"/";
  event.waitUntil(self.clients.matchAll({type:"window",includeUncontrolled:true}).then(list=>{
    for(const client of list){if("focus" in client){client.navigate(path);return client.focus()}}
    return self.clients.openWindow(path);
  }));
});
