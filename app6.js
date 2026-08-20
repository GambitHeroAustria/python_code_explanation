// Solo bottle identities and room-specific tasting choices.
// Loaded after app5.js so these declarations intentionally override the generic solo UI.
const SOLO_WINE_CARDS={
  SOLOW1:{
    category:'Sancerre · Sauvignon Blanc',
    name:'Sancerre „Enclos de Maimbray“ 2022',
    producer:'M. & E. Roblin',
    image:'assets/solo-sancerre-enclos-maimbray-2022.jpeg',
    icon:'🥂',
    kind:'still'
  },
  SOLOW2:{
    category:'Prosecco · Schaumwein',
    name:'Expert Club – Prosecco DOC Brut',
    producer:'Italien',
    image:'assets/solo-prosecco-expert-club-brut.jpeg',
    icon:'✨',
    kind:'sparkling'
  },
  SOLOW3:{
    category:'Sherry · Fino',
    name:'Tío Pepe – Fino Muy Seco',
    producer:'González Byass · Jerez',
    image:'assets/solo-tio-pepe-fino.jpeg',
    icon:'🍸',
    kind:'sherry'
  }
};

const SOLO_ROOM_AROMAS={
  SOLOW1:{
    zitrus_grapefruit:'Zitrone & Grapefruit',
    pfirsich_aprikose:'Pfirsich & Aprikose',
    bluete_holunder:'Weiße Blüten & Holunder',
    kraeuter_gras:'Kräuter & frisches Gras',
    feuerstein_mineral:'Feuerstein & Mineralik',
    apfel_birne:'Apfel & Birne',
    honig_vanille:'Honig & Vanille'
  },
  SOLOW2:{
    apfel_birne:'Apfel & Birne',
    pfirsich_aprikose:'Pfirsich & Aprikose',
    bluete_holunder:'Weiße Blüten & Holunder',
    zitrus_grapefruit:'Zitrone & Grapefruit',
    exotische_fruechte:'Ananas, Maracuja & Exotik',
    kraeuter_gras:'Kräuter & frisches Gras',
    honig_vanille:'Honig & Vanille'
  },
  SOLOW3:{
    mandel_nuss:'Mandel & Nuss',
    hefe_brot:'Hefe & Brotteig',
    olive_salzlake:'Grüne Olive & Salzlake',
    zitrus_grapefruit:'Zitrone & Grapefruit',
    apfel_birne:'Grüner Apfel & Birne',
    kraeuter_gras:'Kräuter & Kamille',
    feuerstein_mineral:'Kreide & Mineralik'
  }
};

const SOLO_GUESS_OPTIONS={
  SOLOW1:{
    grape:['Sauvignon Blanc','Chardonnay','Riesling','Petit Courbu/Petit Manseng'],
    region:['Loire','Burgund','Elsass','Südwestfrankreich'],
    price:['unter 10 €','10–20 €','20–30 €','über 30 €']
  },
  SOLOW2:{
    grape:['Glera','Chardonnay','Sauvignon Blanc','Riesling'],
    region:['Prosecco DOC','Franciacorta','Loire','Mosel'],
    price:['unter 10 €','10–20 €','20–30 €','über 30 €']
  },
  SOLOW3:{
    grape:['Palomino Fino','Pedro Ximénez','Moscatel','Glera'],
    region:['Jerez','Montilla-Moriles','Madeira','Marsala'],
    price:['unter 10 €','10–20 €','20–30 €','über 30 €']
  }
};


function hydrateSoloImages(){}
function soloWineMeta(code=R){return SOLO_WINE_CARDS[code]||null}
function soloAromaMap(code=R){return SOLO_ROOM_AROMAS[code]||SOLO_AROMAS}
function soloImageByWineName(name=''){
  const s=String(name).toLowerCase();
  if(/maimbray|sancerre/.test(s))return SOLO_WINE_CARDS.SOLOW1;
  if(/prosecco|expert club/.test(s))return SOLO_WINE_CARDS.SOLOW2;
  if(/t[ií]o pepe|fino muy seco|gonz[aá]lez byass/.test(s))return SOLO_WINE_CARDS.SOLOW3;
  return null;
}
function soloBottleFigure(meta,context='taste'){
  if(!meta)return'';
  return `<figure class="solobottle ${e(meta.kind||'still')} ${context==='card'?'compactfigure':''}"><img src="${e(meta.image)}" alt="${e(meta.name)}"><figcaption><span class="ey">${e(meta.category)}</span><strong>${e(meta.name)}</strong><small>${e(meta.producer||'')}</small></figcaption></figure>`
}

function pairCard(r){
  const s=getSession(r.code),phase=r.phase==='tasting'?'Freie Verkostung':r.phase==='profiles'?'Profile offen':'Aufgelöst';
  if(r.tasting_type==='white_solo'){
    const meta=soloWineMeta(r.code);
    return `<section class="card pair solopair ${meta?e(meta.kind):''}"><div class="pairtop"><div><div class="ey">${meta?e(meta.category):'Einzelverkostung'}</div><h3>${meta?e(meta.name):e(r.theme)}</h3></div><span class="pill">${phase}</span></div>${meta?soloBottleFigure(meta,'card'):`<p class="muted small">${e(r.intro||'')}</p>`}<p class="muted small solo-intro">${e(r.intro||'Ein Wein, sensorische Eindrücke und drei Schätzfragen.')}</p><a class="btn ${s?'secondary':'primary'} full center" href="?event=${encodeURIComponent(E)}&room=${encodeURIComponent(r.code)}${KIOSK?'&kiosk=1':''}">${s?'Weiter':'Starten'}</a></section>`;
  }
  const white=isWhiteType(r.tasting_type),olli=r.code==='OLIRED';
  return `<section class="card pair ${white?'whitepair':'redpair'} ${olli?'olliredcard':''}"><div class="pairtop"><div class="pairidentity">${olli?blindDuoIcon():`<div class="standardicon">${white?'🥂':'🍷'}</div>`}<div><div class="ey">${olli?'Blindes Rotwein-Duo':white?'Weißwein-Duo':'Rotwein-Duo'}</div><h3>${e(r.theme)}</h3></div></div><span class="pill">${phase}</span></div><p class="muted small">${e(r.intro||'')}</p><a class="btn ${s?'secondary':'primary'} full center" href="?event=${encodeURIComponent(E)}&room=${encodeURIComponent(r.code)}${KIOSK?'&kiosk=1':''}">${s?'Weiter':'Starten'}</a></section>`;
}

function soloAromas(){
  const map=soloAromaMap();
  return `<div class="ttl">Aromarichtungen – 2 bis 4 auswählen</div><div class="grid two aroma-grid">${Object.entries(map).map(([id,label])=>`<button class="choice ${soloAns.aromas.includes(id)?'on':''}" data-solo-a="${id}">${e(label)}</button>`).join('')}</div><p class="small muted">${soloAns.aromas.length}/4 gewählt</p>`;
}

function soloTaste(){
  const done=soloComplete(),meta=soloWineMeta();
  const identity=meta?soloBottleFigure(meta,'taste'):'';
  const title=meta?.kind==='sherry'?'Deinen Sherry bewerten':meta?.kind==='sparkling'?'Deinen Prosecco bewerten':'Deinen Wein bewerten';
  A.innerHTML=brand(`<span class="room">${meta?e(meta.category):e(soloState.theme||R)}</span>`)+`<div class="toprow">${backLink()}</div>${identity}<section class="card tasting"><div class="sectiontitle"><span>${meta?meta.icon:'🥂'}</span><div><b>${title}</b><p class="muted small">Die Flasche ist bekannt. Referenzprofil, richtige Schätzungen und Punkte bleiben bis zur Host-Freigabe gesperrt.</p></div></div>${soloPick('nose_intensity','Duft- & Fruchtintensität')}${soloAromas()}${soloPick('oak','Schmelz & Cremigkeit')}${soloPick('body','Körper & Fülle')}${soloPick('tannin','Süße-Eindruck · 1 knochentrocken, 5 deutlich süß')}${soloPick('acidity','Säure · 1 mild, 5 sehr hoch')}${soloPick('freshness','Frische · 1 matt, 5 sehr frisch')}${soloPick('finish','Länge des Abgangs · 1 kurz, 5 sehr lang')}${soloPick('finish_intensity','Intensität des Abgangs · 1 kaum, 5 sehr intensiv')}<div class="field"><label>Eine Beobachtung <span class="muted small">(optional)</span></label><input id="solo-note" maxlength="180" value="${e(soloAns.note||'')}"></div></section><section class="card compact">${done?'<b>✓ Verkostung vollständig</b><button id="solo-guesses" class="btn primary full">Zu den Schätzfragen</button>':'<b>Noch nicht vollständig</b>'}</section>`;
  document.querySelectorAll('[data-solo-k]').forEach(x=>x.onclick=()=>{soloAns[x.dataset.soloK]=+x.dataset.v;soloSave();soloTaste()});
  document.querySelectorAll('[data-solo-a]').forEach(x=>x.onclick=()=>{const id=x.dataset.soloA,a=soloAns.aromas;soloAns.aromas=a.includes(id)?a.filter(v=>v!==id):a.length<4?[...a,id]:a;soloSave();soloTaste()});
  const note=document.getElementById('solo-note');if(note)note.oninput=x=>{soloAns.note=x.target.value;soloSave()};
  const go=document.getElementById('solo-guesses');if(go)go.onclick=()=>soloGuesses();
}

function soloGuesses(){
  const opts=soloState?.guess_options||SOLO_GUESS_OPTIONS[R]||SOLO_GUESS_OPTIONS.SOLOW1,g={},meta=soloWineMeta();
  const block=(k,l)=>`<div class="ttl">${l}</div><div class="grid two">${opts[k].map(v=>`<button class="choice" data-solo-g="${k}" data-v="${e(v)}">${e(v)}</button>`).join('')}</div>`;
  A.innerHTML=brand(`<span class="room">${meta?e(meta.category):'Einzelverkostung'}</span>`)+`<div class="toprow">${backLink()}</div>${meta?soloBottleFigure(meta,'guess'):''}<section class="card"><h2>Drei Schätzfragen</h2><p class="muted small">Die Flasche ist sichtbar – gefragt sind Rebsorte, Herkunft und Preisniveau.</p>${block('grape','Rebsorte')}${block('region','Region / Herkunft')}${block('price','Preisklasse')}<button id="solo-send" class="btn primary full">Antworten speichern</button></section>`;
  document.querySelectorAll('[data-solo-g]').forEach(x=>x.onclick=()=>{g[x.dataset.soloG]=x.dataset.v;x.parentElement.querySelectorAll('.choice').forEach(y=>y.classList.remove('on'));x.classList.add('on')});
  const send=document.getElementById('solo-send');send.onclick=async()=>{if(!g.grape||!g.region||!g.price)return toast('Bitte alle drei Fragen beantworten');send.disabled=true;try{await rpc('solo_save_guesses',{p_code:R,p_token:getSession(R).token,p_grape:g.grape,p_region:g.region,p_price:g.price});soloWaiting()}catch(x){send.disabled=false;toast(x.message||'Speichern fehlgeschlagen')}};
}

function soloWaiting(){
  const meta=soloWineMeta();
  A.innerHTML=brand(`<span class="room">${meta?e(meta.category):'Einzelverkostung'}</span>`)+`<div class="toprow">${backLink()}</div>${meta?soloBottleFigure(meta,'wait'):''}<section class="card wait"><h2>Antworten gespeichert</h2><p class="muted">Referenzprofil und Punkte erscheinen, sobald der Host sie freigibt.</p></section>`;
  poll=setInterval(async()=>{const x=await rpc('solo_get_state',{p_code:R,p_token:getSession(R).token});if(x.phase==='revealed')roomBoot()},4000);
}

async function soloReveal(){
  clearPoll();
  const r=await rpcCompat('solo_get_reveal_v2','solo_get_reveal',{p_code:R,p_token:getSession(R).token}),me=(r.players||r.leaderboard||[]).find(x=>String(x.name).toLowerCase()===String(getSession(R).name).toLowerCase()),meta=soloWineMeta()||soloImageByWineName(r.wine?.name||'');
  const d=r.wine?.details||{};
  const details=(r.players||[]).map(p=>soloPlayerReveal(p,String(p.name).toLowerCase()===String(getSession(R).name).toLowerCase())).join('');
  A.innerHTML=brand(`<span class="room">Auflösung</span>`)+`<div class="toprow">${backLink()}</div>${meta?soloBottleFigure(meta,'reveal'):''}<section class="card hero revealhero soloresult"><div class="ey">Dein Ergebnis</div><div class="heroresult"><div><h2>${e(me?.name||getSession(R).name)}</h2><p>Sensorik, Aromen und drei Schätzfragen</p></div><div class="totalscore">${revealScore(me?.score)}<small>/ ${revealScore(me?.max_score||27)}</small></div></div>${me?.breakdown?soloScoreStory(me.breakdown):''}</section><section class="card"><h3>${e(r.wine.name)} ${e(r.wine.vintage||'')}</h3><p class="muted">${e(d.summary||d.sources_summary||'')}</p>${d.dossier?`<p>${e(d.dossier)}</p>`:''}${d.grapes?`<p><b>Rebsorte:</b> ${e(d.grapes)}</p>`:''}${d.region?`<p><b>Herkunft:</b> ${e(d.region)}</p>`:''}<p><b>Servieren:</b> ${e(d.serve||d.serving||'–')}</p></section>${r.correct_guesses?soloCorrectAnswers(r):''}${details?`<section class="resultsection"><div class="sectionheading"><span>🎯</span><div><h2>Detailauswertung</h2><p>Alle Werte, Aromentreffer und Tipps pro Person</p></div></div><div class="soloplayergrid">${details}</div></section>`:''}<section class="card"><h3>Leaderboard</h3>${roomRanks(r.leaderboard)}</section>`;
}

const SOLO_METRIC_LABELS={nose_intensity:'Duft- & Fruchtintensität',oak:'Schmelz & Cremigkeit',body:'Körper & Fülle',tannin:'Süße-Eindruck',acidity:'Säure',freshness:'Frische',finish:'Länge des Abgangs',finish_intensity:'Intensität des Abgangs'};
const SOLO_GUESS_LABELS={grape:'Rebsorte',region:'Region / Herkunft',price:'Preisklasse'};
function soloScoreStory(b){const rows=[['Qualitative Werte',b.metrics,b.metrics_max],['Aromen',b.aromas,b.aromas_max],['Schätzfragen',b.quiz,b.quiz_max]];return `<div class="scorestory soloscorestory">${rows.map(([label,value,max])=>`<div><div class="barlabel"><span>${label}</span><b>${revealScore(value)}/${revealScore(max)}</b></div><div class="bar"><i style="width:${max?Math.min(100,100*Number(value||0)/Number(max)):0}%"></i></div></div>`).join('')}</div>`}
function soloMetricResult(m){const diff=Math.abs(Number(m.value)-Number(m.target)),tone=diff===0?'exact':diff===1?'near':'miss';return `<div class="resultmetric ${tone}"><div class="resultmetrichead"><b>${e(SOLO_METRIC_LABELS[m.key]||m.key)}</b><span>Wert ${e(m.value)} · Ziel ${e(m.target)} · ${revealScore(m.score)}/${revealScore(m.max)} P.</span></div><div class="resultscale">${[1,2,3,4,5].map(v=>`<span class="${v===Number(m.value)?'mine ':''}${v===Number(m.target)?'target ':''}${v===Number(m.value)&&v===Number(m.target)?'both':''}">${v}</span>`).join('')}</div><div class="scalelegend"><span>gewählt</span><span>Zielwert</span></div></div>`}
function soloGuessResult(g){return `<div class="sologuess ${g.correct?'correct':'wrong'}"><div><small>${e(SOLO_GUESS_LABELS[g.key]||g.key)}</small><b>${e(g.selected||'–')}</b>${g.correct?'':`<span>Richtig: ${e(g.expected||'–')}</span>`}</div><strong>${g.correct?'✓':'✕'} ${revealScore(g.score)}/${revealScore(g.max)} P.</strong></div>`}
function soloAromaChips(ids,tone){return (ids||[]).map(id=>`<span class="aromatag ${tone}">${e(soloAromaMap()[id]||id)}</span>`).join('')||'<span class="muted tiny">keine</span>'}
function soloPlayerReveal(p,isMe){const a=p.aromas||{};return `<article class="card soloplayer ${isMe?'isme':''}"><div class="personalhead"><div><div class="ey">${isMe?'Deine Auswertung':'Mitspieler'}</div><h3>${e(p.name)}</h3></div><div class="roundscore">${revealScore(p.score)}<small>/ ${revealScore(p.max_score||27)}</small></div></div>${soloScoreStory(p.breakdown||{})}<h4>Schätzfragen</h4><div class="sologuesses">${(p.guesses||[]).map(soloGuessResult).join('')}</div><h4>Qualitative Werte</h4>${(p.metrics||[]).map(soloMetricResult).join('')}<div class="aromaresult"><div class="resultmetrichead"><b>Aromarichtungen</b><span>${revealScore(a.score)}/${revealScore(a.max)} P.</span></div><div class="aromagroups"><div><small>Getroffen</small><div class="aromachips">${soloAromaChips(a.matched,'hit')}</div></div><div><small>Im Zielprofil, nicht gewählt</small><div class="aromachips">${soloAromaChips(a.missed,'missed')}</div></div><div><small>Zusätzlich gewählt</small><div class="aromachips">${soloAromaChips(a.extra,'extra')}</div></div></div></div>${p.note?`<blockquote>„${e(p.note)}“</blockquote>`:''}</article>`}
function soloCorrectAnswers(r){const labels=SOLO_GUESS_LABELS,options=r.quiz_options||{};return `<section class="card correctanswers"><div class="sectionheading compactheading"><span>✅</span><div><h2>Richtige Schätzantworten</h2><p>Diese Werte stammen aus denselben Optionslisten wie bei der Abgabe.</p></div></div><div class="correctanswergrid">${Object.entries(r.correct_guesses).map(([key,value])=>`<div><small>${e(labels[key]||key)}</small><b>${e(value)}</b><span>${(options[key]||[]).includes(value)?'✓ war auswählbar':'⚠ nicht in der Auswahl'}</span></div>`).join('')}</div></section>`}

function revealAromaLabel(id,type){
  const labels={};Object.values(SOLO_ROOM_AROMAS).forEach(m=>Object.assign(labels,m));
  return(type==='white_simple'?{...SOLO_AROMAS,...labels}:RED_SIMPLE_AROMAS)[id]||String(id).replaceAll('_',' ');
}

function compactWine(w,i){
  if(!w)return'';
  const p=w.profile||{},x=w.details||{},meta=soloImageByWineName(w.name||'');
  const visual=meta?`<img class="archivephoto" src="${e(meta.image)}" alt="${e(meta.name)}">`:`<div class="archivebottle">${i+1}</div>`;
  return `<article class="archivewine ${meta?'withphoto':''}">${visual}<div><div class="ey">Wein ${i+1}</div><h4>${e(w.name)} ${e(w.vintage||'')}</h4><p>${e(p.summary||'')}</p><div class="archivefacts">${x.producer?`<span><b>Winzer</b>${e(x.producer)}</span>`:''}${x.region?`<span><b>Region</b>${e(x.region)}</span>`:''}${x.grapes?`<span><b>Rebsorten</b>${e(x.grapes)}</span>`:''}${(x.serve||x.serving)?`<span><b>Servieren</b>${e(x.serve||x.serving)}</span>`:''}</div>${Array.isArray(p.key)?`<div class="tags">${p.key.slice(0,7).map(a=>`<span class="tag strong">${e(a)}</span>`).join('')}</div>`:''}</div></article>`;
}
