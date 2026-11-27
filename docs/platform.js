/* Bilan trading, version web.
   Connexion par e-mail et stockage dans Supabase, avec la même interface que la version Claude
   (window.claude.use('db' | 'user' | 'assets')), pour que l'appli soit la même dans les deux versions. */
(function () {
  'use strict';
  const C = window.BT_CONF = window.BT_CONF || {};
  C.web = true;
  C.imgUrl = id => {
    const s = String(id), i = s.indexOf('_');
    return (C.url || '') + '/storage/v1/object/public/captures/' + (i > 0 ? s.slice(0, i) + '/' + s.slice(i + 1) : s);
  };
  const P = window.BT_PLATFORM = { email: '', signOut: async () => {} };

  /* ---------- écran de connexion ---------- */
  const css = document.createElement('style');
  css.textContent = `
#auth{position:fixed;inset:0;z-index:200;background:var(--bg);color:var(--ink);overflow:auto;display:flex;flex-direction:column}
#auth .a-top{background:#b8f5d0;color:#0b0b0b;padding:calc(env(safe-area-inset-top) + 36px) max(6vw,20px) 30px}
#auth .a-top h1{font:700 clamp(34px,9vw,52px)/1.02 "Space Grotesk",Inter,system-ui,sans-serif;margin:0}
#auth .a-top p{margin:10px 0 0;font-size:16px;max-width:34ch}
#auth form{width:100%;max-width:440px;padding:26px max(6vw,20px) calc(env(safe-area-inset-bottom) + 30px);display:grid;gap:14px}
#auth h2{margin:0}
#auth .a-msg{margin:0;font-weight:600}#auth .a-msg:empty{display:none}#auth .a-msg.err{color:var(--losstx)}
#auth .a-links{display:grid;gap:4px;justify-items:start}
#auth .a-link{background:none;border:0;padding:8px 0;min-height:40px;color:var(--ink);font:600 15px Inter,system-ui,sans-serif;text-decoration:underline;cursor:pointer}
#auth .btn{width:100%}`;
  document.head.appendChild(css);

  const box = document.createElement('div');
  box.id = 'auth';
  box.hidden = true;
  box.innerHTML = `<div class="a-top"><h1>Bilan trading</h1><p>Votre journal de trading : bilan, journal de bord, conseils et défis entre amis.</p></div>
<form novalidate><h2 id="a-title">Connexion</h2>
<label id="a-pseudoL">Prénom ou pseudo <span class="hint">visible par les autres membres</span><input id="a-pseudo" maxlength="40" autocomplete="nickname"></label>
<label id="a-emailL">E-mail<input id="a-email" type="email" inputmode="email" autocomplete="email" autocapitalize="off" spellcheck="false"></label>
<label id="a-passL"><span id="a-passT">Mot de passe</span><input id="a-pass" type="password" autocomplete="current-password"></label>
<p class="a-msg" id="a-msg" role="alert"></p>
<p class="hint" id="a-info" hidden>Vos comptes de trading restent privés tant que vous ne les rendez pas visibles. L’administrateur du site voit la liste des membres (pseudo, e-mail, date d’inscription, nombre de trades).</p>
<button class="btn" type="submit" id="a-go">Se connecter</button>
<div class="a-links" id="a-links"></div></form>`;
  document.body.appendChild(box);
  const $ = s => box.querySelector(s);
  let mode = 'login';
  const MODES = {
    login: { t: 'Connexion', go: 'Se connecter', pseudo: false, email: true, pass: true, passT: 'Mot de passe', ac: 'current-password',
      links: [['signup', 'Pas encore de compte ? Créer un compte'], ['forgot', 'Mot de passe oublié ?']] },
    signup: { t: 'Créer un compte', go: 'Créer mon compte', pseudo: true, email: true, pass: true, passT: 'Mot de passe (8 caractères ou plus)', ac: 'new-password',
      links: [['login', 'Déjà un compte ? Se connecter']] },
    forgot: { t: 'Mot de passe oublié', go: 'Recevoir un lien par e-mail', pseudo: false, email: true, pass: false,
      links: [['login', 'Retour à la connexion']] },
    reset: { t: 'Nouveau mot de passe', go: 'Enregistrer', pseudo: false, email: false, pass: true, passT: 'Nouveau mot de passe (8 caractères ou plus)', ac: 'new-password', links: [] },
    setup: { t: 'Appli pas encore configurée', go: '', pseudo: false, email: false, pass: false, links: [] }
  };
  function show(m, msg, isErr) {
    mode = m; const d = MODES[m];
    $('#a-title').textContent = d.t; $('#a-go').textContent = d.go; $('#a-go').hidden = !d.go;
    $('#a-pseudoL').hidden = !d.pseudo; $('#a-emailL').hidden = !d.email; $('#a-passL').hidden = !d.pass; $('#a-info').hidden = m !== 'signup';
    if (d.pass) { $('#a-passT').textContent = d.passT; $('#a-pass').autocomplete = d.ac; }
    $('#a-links').innerHTML = d.links.map(([k, l]) => `<button type="button" class="a-link" data-m="${k}">${l}</button>`).join('');
    say(msg || '', isErr);
    box.hidden = false; document.documentElement.style.overflow = 'hidden';
  }
  function hide() { box.hidden = true; document.documentElement.style.overflow = ''; }
  function say(t, isErr) { const m = $('#a-msg'); m.textContent = t; m.classList.toggle('err', !!isErr); }
  function aMsg(e) {
    const c = String(e && e.code || ''), m = String(e && e.message || '').toLowerCase();
    if (c === 'invalid_credentials' || m.includes('invalid login')) return 'E-mail ou mot de passe incorrect.';
    if (c === 'email_not_confirmed' || m.includes('not confirmed')) return 'Confirmez d’abord votre e-mail : touchez le lien reçu par e-mail, puis revenez ici.';
    if (c === 'user_already_exists' || m.includes('already registered')) return 'Un compte existe déjà avec cet e-mail : connectez-vous.';
    if (c === 'weak_password' || m.includes('password should')) return 'Mot de passe trop faible : 8 caractères ou plus, avec des lettres et des chiffres.';
    if (c.includes('rate_limit') || m.includes('rate limit') || m.includes('security purposes')) return 'Trop d’essais d’un coup. Patientez une minute, puis réessayez.';
    if (c === 'email_address_invalid' || (m.includes('email') && m.includes('invalid'))) return 'Cette adresse e-mail n’est pas valide.';
    if (m.includes('fetch') || m.includes('network') || m.includes('load failed')) return 'Pas de connexion internet. Réessayez.';
    return 'Une erreur est survenue. Réessayez.';
  }
  box.addEventListener('click', e => { const b = e.target.closest('[data-m]'); if (b) show(b.dataset.m); });

  if (!C.url || !C.key || !window.supabase || /REMPLACER/.test(C.url + C.key)) {
    window.claude = { use: () => new Promise(() => {}) };
    show('setup', 'Il manque l’adresse et la clé Supabase dans config.js.', true);
    return;
  }

  const sb = window.supabase.createClient(C.url, C.key, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, storageKey: 'bt-auth' } });
  let SESSION = null, started = false, ready;
  const authReady = new Promise(r => { ready = r; });
  const uid = () => SESSION && SESSION.user && SESSION.user.id;
  const pseudo = () => { const u = SESSION && SESSION.user || {}, m = u.user_metadata || {}; return String(m.pseudo || (u.email || '').split('@')[0] || 'Trader').slice(0, 40); };
  P.signOut = async () => {
    try { await sb.auth.signOut(); } catch (e) {}
    try { localStorage.removeItem('bt-compte'); } catch (e) {}
    location.replace(location.pathname);
  };

  box.querySelector('form').addEventListener('submit', async e => {
    e.preventDefault();
    const go = $('#a-go'), email = $('#a-email').value.trim(), pass = $('#a-pass').value, ps = $('#a-pseudo').value.trim();
    if (MODES[mode].email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { say('Indiquez une adresse e-mail valide.', true); return; }
    if ((mode === 'signup' || mode === 'reset') && pass.length < 8) { say('Le mot de passe doit faire 8 caractères ou plus.', true); return; }
    if (mode === 'login' && !pass) { say('Indiquez votre mot de passe.', true); return; }
    if (mode === 'signup' && !ps) { say('Indiquez un prénom ou un pseudo.', true); return; }
    go.disabled = true; say('Un instant…');
    try {
      if (mode === 'login') {
        const { data, error } = await sb.auth.signInWithPassword({ email, password: pass });
        if (error) throw error;
        if (data && data.session) start(data.session);
      } else if (mode === 'signup') {
        const { data, error } = await sb.auth.signUp({ email, password: pass, options: { data: { pseudo: ps }, emailRedirectTo: C.appUrl || location.href.split('#')[0] } });
        if (error) throw error;
        if (data && data.session) start(data.session);
        else show('login', 'Compte créé ! Ouvrez l’e-mail de confirmation et touchez le lien, puis revenez ici pour vous connecter. (Si vous aviez déjà un compte avec cet e-mail, connectez-vous directement.)');
      } else if (mode === 'forgot') {
        const { error } = await sb.auth.resetPasswordForEmail(email, { redirectTo: C.appUrl || location.href.split('#')[0] });
        if (error) throw error;
        show('login', 'Si un compte existe avec cet e-mail, un lien pour changer le mot de passe vient de vous être envoyé.');
      } else if (mode === 'reset') {
        const { error } = await sb.auth.updateUser({ password: pass });
        if (error) throw error;
        recovering = false;
        const { data } = await sb.auth.getSession();
        if (data && data.session) start(data.session); else show('login', 'Mot de passe changé. Connectez-vous.');
      }
    } catch (x) { say(aMsg(x), true); }
    finally { go.disabled = false; }
  });

  let recovering = /type=recovery/.test(location.hash + location.search);
  sb.auth.onAuthStateChange((ev, s) => {
    if (s) SESSION = s;
    if (ev === 'PASSWORD_RECOVERY') { recovering = true; show('reset'); return; }
    if (recovering) { if (ev === 'INITIAL_SESSION' && s) show('reset'); return; }
    if (s && !started) setTimeout(() => start(s), 0);
    else if (!s && !started && (ev === 'INITIAL_SESSION' || ev === 'SIGNED_OUT')) show('login');
  });

  function start(s) {
    if (started) return;
    started = true; SESSION = s; P.email = s.user.email || '';
    hide();
    fetchDoc('profils/' + uid()).then(cur => { if (!cur || typeof cur.nom !== 'string') return db.doc('profils/' + uid()).set(Object.assign({ inscrit: new Date().toISOString() }, cur || {}, { nom: pseudo() })); }).catch(() => {});
    ready();
  }

  /* ---------- base de données (table docs) ---------- */
  const parentOf = p => p.slice(0, p.lastIndexOf('/'));
  const clone = d => JSON.parse(JSON.stringify(d));
  const rid = n => { const a = new Uint8Array(n); crypto.getRandomValues(a); return Array.from(a, b => 'abcdefghijklmnopqrstuvwxyz0123456789'[b % 36]).join(''); };
  const meta = { fromCache: false, hasPendingWrites: false };
  const dsnap = (p, d) => ({ id: p.slice(p.lastIndexOf('/') + 1), exists: d != null, data: () => (d == null ? undefined : d), metadata: meta });
  const csnap = rows => { const docs = rows.map(r => dsnap(r.path, r.data)); return { docs, size: docs.length, empty: !docs.length, docChanges: () => [], metadata: meta }; };
  function dbErr(e) {
    const c = String(e && e.code || ''), m = String(e && e.message || '').toLowerCase();
    if (c === '42501' || m.includes('row-level security') || m.includes('permission')) return { code: 'invalid_argument', message: e.message };
    if (c === '23514' || m.includes('too large')) return { code: 'quota_exceeded', message: e.message };
    return { code: 'unavailable', message: e && e.message || '' };
  }
  async function fetchDoc(p) {
    const { data, error } = await sb.from('docs').select('data').eq('path', p).maybeSingle();
    if (error) throw dbErr(error);
    return data ? data.data : null;
  }
  async function fetchCol(cp) {
    let out = [];
    for (let from = 0; ; from += 1000) {
      const { data, error } = await sb.from('docs').select('path,data').eq('parent', cp).order('path').range(from, from + 999);
      if (error) throw dbErr(error);
      out = out.concat(data || []);
      if (!data || data.length < 1000) break;
    }
    return out;
  }
  const subs = new Set();
  async function refresh(s) {
    const v = s.ver;
    try {
      if (s.kind === 'doc') { const d = await fetchDoc(s.path); if (v !== s.ver || !subs.has(s)) return; s.last = d; s.next(dsnap(s.path, d)); }
      else { const rows = await fetchCol(s.path); if (v !== s.ver || !subs.has(s)) return; s.last = rows; s.next(csnap(rows)); }
    } catch (e) { if (!s.failed && s.err) { s.failed = true; try { s.err(e); } catch (x) {} } }
  }
  function applyLocal(rows) {
    for (const s of subs) {
      if (s.kind === 'doc') {
        const r = rows.filter(x => x.path === s.path).pop();
        if (r) { s.ver++; s.last = r.data; queueMicrotask(() => s.next(dsnap(s.path, r.data))); }
      } else if (s.last) {
        const mine = rows.filter(x => parentOf(x.path) === s.path);
        if (!mine.length) continue;
        const map = new Map(s.last.map(x => [x.path, x]));
        for (const r of mine) { if (r.data == null) map.delete(r.path); else map.set(r.path, { path: r.path, data: r.data }); }
        const list = [...map.values()].sort((a, b) => (a.path < b.path ? -1 : a.path > b.path ? 1 : 0));
        s.ver++; s.last = list; queueMicrotask(() => s.next(csnap(list)));
      }
    }
  }
  function refreshAround(paths) { for (const s of subs) if (paths.some(p => s.path === p || s.path === parentOf(p))) refresh(s); }
  async function writeRows(rows) {
    applyLocal(rows);
    const now = new Date().toISOString();
    const { error } = await sb.from('docs').upsert(rows.map(r => ({ path: r.path, parent: parentOf(r.path), owner: uid(), data: r.data, updated_at: now })));
    if (error) { refreshAround(rows.map(r => r.path)); throw dbErr(error); }
  }
  function cachedDoc(p) {
    for (const s of subs) {
      if (s.kind === 'doc' && s.path === p && s.last != null) return s.last;
      if (s.kind === 'col' && s.path === parentOf(p) && s.last) { const r = s.last.find(x => x.path === p); if (r) return r.data; }
    }
    return null;
  }
  function docRef(p) {
    if (p.split('/').length % 2) throw new TypeError('Chemin de document invalide : ' + p);
    return {
      id: p.slice(p.lastIndexOf('/') + 1), path: p,
      get: async () => dsnap(p, await fetchDoc(p)),
      set: async d => writeRows([{ path: p, data: clone(d) }]),
      update: async d => {
        let cur = cachedDoc(p); if (cur == null) cur = await fetchDoc(p);
        if (cur == null) throw { code: 'invalid_argument', message: 'Document absent' };
        return writeRows([{ path: p, data: Object.assign({}, cur, clone(d)) }]);
      },
      delete: async () => {
        applyLocal([{ path: p, data: null }]);
        const { error } = await sb.from('docs').delete().eq('path', p);
        if (error) { refreshAround([p]); throw dbErr(error); }
      },
      collection: c => colRef(p + '/' + c),
      onSnapshot: (next, err) => subscribe({ kind: 'doc', path: p, next, err })
    };
  }
  function colRef(cp) {
    if (cp.split('/').length % 2 === 0) throw new TypeError('Chemin de collection invalide : ' + cp);
    return {
      path: cp,
      doc: id => docRef(cp + '/' + (id || rid(20))),
      get: async () => csnap(await fetchCol(cp)),
      onSnapshot: (next, err) => subscribe({ kind: 'col', path: cp, next, err })
    };
  }
  function subscribe(s) { s.ver = 0; s.last = null; subs.add(s); refresh(s); return () => subs.delete(s); }
  const db = { doc: docRef, collection: colRef, setMany: async entries => writeRows(entries.map(e => ({ path: e.path, data: clone(e.data) }))) };

  /* Les données des autres (partage, défis, noms) se rafraîchissent toutes les 30 s ; tout se recharge quand l'appli revient au premier plan. */
  setInterval(() => { if (document.visibilityState === 'visible') for (const s of subs) if (!s.path.startsWith('data/users/')) refresh(s); }, 30000);
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') subs.forEach(refresh); });
  window.addEventListener('online', () => subs.forEach(refresh));

  /* ---------- utilisateur ---------- */
  const user = {
    id: async () => uid(),
    can: async () => true, canEdit: async () => false, isOwner: async () => false,
    me: async () => ({ id: uid(), name: pseudo() }),
    profiles: async ids => {
      const out = {}, list = [...new Set(ids)].filter(Boolean).slice(0, 200);
      if (!list.length) return out;
      const { data } = await sb.from('docs').select('path,data').in('path', list.map(i => 'profils/' + i));
      (data || []).forEach(r => { out[r.path.slice(8)] = { name: String(r.data && r.data.nom || '') }; });
      return out;
    }
  };

  /* ---------- captures d'écran (Supabase Storage) ---------- */
  const assets = {
    upload: async (blob, o) => {
      const type = (o && o.type) || blob.type || 'image/jpeg', r = rid(24), id = uid() + '_' + r;
      const { error } = await sb.storage.from('captures').upload(uid() + '/' + r, blob, { contentType: type, upsert: false, cacheControl: '31536000' });
      if (error) {
        const m = String(error.message || '').toLowerCase();
        throw { code: m.includes('size') || m.includes('large') ? 'too_large' : m.includes('mime') || m.includes('type') ? 'unsupported_type' : m.includes('quota') ? 'quota_or_state' : 'upstream_error', message: error.message };
      }
      return { id, url: C.imgUrl(id), sizeBytes: blob.size, contentType: type };
    },
    delete: async id => {
      const s = String(id), i = s.indexOf('_'); if (i < 1) return { deleted: false };
      const { error } = await sb.storage.from('captures').remove([s.slice(0, i) + '/' + s.slice(i + 1)]);
      return { deleted: !error };
    },
    list: async () => ({ assets: [], usage: {} })
  };

  /* ---------- fonctions propres au site : communauté, discussions, administration, MT5 ---------- */
  function apiErr(e) {
    const c = String(e && e.code || ''), m = String(e && e.message || '');
    if (c === 'PGRST205' || c === 'PGRST202' || c === '42P01' || c === '42883' || /could not find/i.test(m)) return { code: 'not_installed', message: m };
    if (c === '42501' || /row-level security|permission/i.test(m)) return { code: 'forbidden', message: m };
    if (/Réservé|retirer vous-même/.test(m)) return { code: 'forbidden', message: m };
    return { code: 'unavailable', message: m };
  }
  const ok = ({ data, error }) => { if (error) throw apiErr(error); return data; };
  const COLS = 'id,auteur,type,texte,images,stats,cree,expire';
  P.uid = () => uid();
  P.upload = blob => assets.upload(blob);
  P.social = {
    posts: async ({ avant, auteur, type, limite } = {}) => {
      let q = sb.from('posts').select(COLS).neq('type', 'story').order('cree', { ascending: false }).limit(limite || 20);
      if (avant) q = q.lt('cree', avant); if (auteur) q = q.eq('auteur', auteur); if (type) q = q.eq('type', type);
      return ok(await q) || [];
    },
    stories: async () => ok(await sb.from('posts').select(COLS).eq('type', 'story').gt('expire', new Date().toISOString()).order('cree', { ascending: true }).limit(300)) || [],
    publier: async ({ type, texte, images, stats, story }) => {
      const row = { type: story ? 'story' : (type || 'libre'), texte: String(texte || '').slice(0, 4000), images: (images || []).slice(0, 10), stats: stats || null };
      if (story) row.expire = new Date(Date.now() + 24 * 3600e3).toISOString();
      return ok(await sb.from('posts').insert(row).select(COLS).single());
    },
    supprimer: async id => { ok(await sb.from('posts').delete().eq('id', id)); },
    likes: async ids => ids.length ? ok(await sb.from('likes').select('post,auteur').in('post', ids)) || [] : [],
    aimer: async (id, on) => { if (on) ok(await sb.from('likes').upsert({ post: id, auteur: uid() }, { ignoreDuplicates: true })); else ok(await sb.from('likes').delete().eq('post', id).eq('auteur', uid())); },
    nbCommentaires: async ids => { const m = {}; if (!ids.length) return m; (ok(await sb.from('commentaires').select('post').in('post', ids)) || []).forEach(r => { m[r.post] = (m[r.post] || 0) + 1; }); return m; },
    commentaires: async post => ok(await sb.from('commentaires').select('id,post,auteur,texte,cree').eq('post', post).order('cree', { ascending: true }).limit(300)) || [],
    commenter: async (post, texte) => ok(await sb.from('commentaires').insert({ post, texte: String(texte).slice(0, 1000) }).select('id,post,auteur,texte,cree').single()),
    supprimerCommentaire: async id => { ok(await sb.from('commentaires').delete().eq('id', id)); }
  };
  P.chat = {
    messages: async defi => ok(await sb.from('messages').select('id,defi,auteur,texte,cree').eq('defi', defi).order('cree', { ascending: true }).limit(300)) || [],
    envoyer: async (defi, texte) => ok(await sb.from('messages').insert({ defi, texte: String(texte).slice(0, 1000) }).select('id,defi,auteur,texte,cree').single()),
    supprimer: async id => { ok(await sb.from('messages').delete().eq('id', id)); }
  };
  P.admin = {
    statut: async () => { const r = await sb.rpc('devenir_admin'); if (r.error) throw apiErr(r.error); return r.data === true; },
    membres: async () => ok(await sb.rpc('liste_membres')) || [],
    bannis: async () => ok(await sb.rpc('liste_bannis')) || [],
    retirer: async (id, bloquer) => ok(await sb.rpc('retirer_membre', { p_membre: id, p_bloquer: !!bloquer })),
    debloquer: async email => ok(await sb.rpc('debloquer_membre', { p_email: email }))
  };
  P.mt5 = {
    url: C.url, key: C.key,
    cles: async () => ok(await sb.from('cles_mt5').select('cle,compte,cree,dernier').order('cree', { ascending: true })) || [],
    creer: async compte => { const cle = rid(40); ok(await sb.from('cles_mt5').insert({ cle, compte })); return cle; },
    supprimer: async cle => { ok(await sb.from('cles_mt5').delete().eq('cle', cle)); }
  };

  window.claude = { use: async n => { await authReady; return n === 'db' ? db : n === 'user' ? user : n === 'assets' ? assets : null; } };

  if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js').catch(() => {});
})();
