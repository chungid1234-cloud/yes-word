'use strict';
(async()=>{
const root=document.getElementById('app'), markerKey='yes-word-device-profile-v1', authKey='yes-word-auth-v1';
document.body.classList.add('welcome-mode');
let launched=false;
const guest={id:'guest-local',guest:true,profile:{id:'guest-local',name:'게스트',affiliation:'개인 / 기타'}};
const guestKey='yes-word-guest-active';
function screen(message,offline){root.replaceChildren();let box=document.createElement('section');box.className='welcome-card';let h=document.createElement('h2');h.textContent='YES WORD';let p=document.createElement('p');p.textContent=message;box.append(h,p);let a=document.createElement('a');a.href='./account.html?v=20';a.textContent='로그인 / 회원가입';box.append(a);let g=document.createElement('button');g.className='outline full';g.textContent='가입 없이 시작하기';g.onclick=()=>{localStorage.setItem(guestKey,'1');launch(guest,null)};box.append(g);if(offline){let b=document.createElement('button');b.className='primary full';b.textContent='이 기기에서 오프라인 암송';b.onclick=()=>launch(offline,null);box.append(b)}root.append(box)}
function read(k){try{return JSON.parse(localStorage.getItem(k))}catch{return null}}
function launch(identity,client){if(launched)return;launched=true;window.YES_IDENTITY=Object.freeze(identity);window.YES_CLIENT=client;document.body.classList.remove('welcome-mode');let script=document.createElement('script');script.src='./app.js?v=20';script.onerror=()=>{launched=false;document.body.classList.add('welcome-mode');screen('앱을 불러오지 못했습니다. 다시 접속해 주세요.')};document.head.append(script)}
screen('계정을 확인하고 있습니다.');
if('serviceWorker'in navigator)navigator.serviceWorker.register('./sw.js').catch(()=>{});
const cached=read(markerKey),session=read(authKey);
const offline=cached?.id&&session?.user?.id===cached.id&&cached.profile?.name?cached:null;
window.addEventListener('storage',e=>{if(e.key===authKey&&launched&&read(authKey)?.user?.id!==window.YES_IDENTITY.id){location.reload()}});
if(localStorage.getItem(guestKey)==='1'&&(!session?.user||new URLSearchParams(location.search).get('guest')==='1')){history.replaceState(null,'',location.pathname);launch(guest,null);return}
if(!navigator.onLine){screen('오프라인 상태입니다. 이전에 로그인한 이 기기에서만 학습할 수 있습니다. 공용 기기에서는 사용하지 마세요.',offline);return}
try{
 await new Promise((resolve,reject)=>{let s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.49.4/dist/umd/supabase.js';s.onload=resolve;s.onerror=reject;document.head.append(s)});
 const client=window.supabase.createClient('https://nheaxjxixixhmhxinqlt.supabase.co','sb_publishable_ORcSnStmZXAuyRxrqtLOTA_ZjJz7naH',{auth:{storageKey:authKey,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
 const {data,error}=await client.auth.getUser();
 if(launched)return;
 if(error||!data.user){if(!error||error.status===401||error.status===403||error.name==='AuthSessionMissingError'){localStorage.removeItem(markerKey);location.replace('./account.html?v=20');return}throw error}
 const user=data.user,r=await client.from('profiles').select('display_name,affiliation').eq('id',user.id).maybeSingle();
 if(launched)return;
 if(r.error)throw r.error;
 if(!r.data){location.replace('./account.html?v=20');return}
 localStorage.removeItem(guestKey);
 const identity={id:user.id,email:user.email,profile:{id:user.id,name:r.data.display_name,affiliation:r.data.affiliation}};
 localStorage.setItem(markerKey,JSON.stringify(identity));
 client.auth.onAuthStateChange((event,s)=>{if(event==='SIGNED_OUT'||(s?.user?.id&&s.user.id!==identity.id)){localStorage.removeItem(markerKey);location.replace('./account.html?v=20')}});
 launch(identity,client);
}catch(e){screen('계정 확인에 실패했습니다. 인터넷 연결을 확인하고 다시 열어 주세요.',null);}
})();
