/* =============================================================================
 *  clp_realtuner - Tablet UI
 * ========================================================================== */
(function () {
    'use strict';

    const app = document.getElementById('app');
    const plateEl = document.getElementById('plate');
    const vinEl   = document.getElementById('vin');
    const meEl    = document.getElementById('me');
    const modeEl  = document.getElementById('mode');
    const diagGrid = document.getElementById('diag-grid');
    const dtcList  = document.getElementById('dtc-list');
    const svcInfo  = document.getElementById('service-info');
    const tabsBtns = document.querySelectorAll('#app .tabs button[data-tab]');
    const tabs     = document.querySelectorAll('#app .tab');
    const tblInstalled = document.querySelector('#parts-installed tbody');
    const tblMissing   = document.querySelector('#parts-missing tbody');
    const tblHistory   = document.querySelector('#history-table tbody');
    const tblPortfolio = document.querySelector('#portfolio-table tbody');
    const personName   = document.getElementById('person-name');
    const personRank   = document.getElementById('person-rank');
    const personXpFill = document.getElementById('person-xp-fill');
    const personXpLabel= document.getElementById('person-xp-label');
    const specGrid     = document.getElementById('spec-grid');
    const certList     = document.getElementById('cert-list');
    const btnClose     = document.getElementById('btn-close');
    const btnRescan    = document.getElementById('btn-rescan');

    let STATE = {};

    const DIAG_FIELDS = [
        { key: 'engine_health',       label: 'Motor' },
        { key: 'transmission_health', label: 'Getriebe' },
        { key: 'brake_health',        label: 'Bremsen' },
        { key: 'turbo_health',        label: 'Turbo' },
        { key: 'suspension_health',   label: 'Fahrwerk' },
    ];

    function post(name, data) {
        const url = `https://${GetParentResourceName()}/${name}`;
        return fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).then((r) => r.json()).catch(() => ({}));
    }
    function GetParentResourceName() { return window.GetParentResourceName ? window.GetParentResourceName() : 'clp_realtuner'; }

    function classForValue(label, value) {
        if (value == null && label) {
            if (label === 'gut' || label === 'ok') return 'ok';
            if (label === 'bedenklich' || label === 'ok') return 'warn';
            return 'bad';
        }
        if (value >= 70) return 'ok';
        if (value >= 40) return 'warn';
        return 'bad';
    }

    function renderDiag() {
        const d = STATE.diag || {};
        plateEl.textContent = d.plate || STATE.plate || '----';
        vinEl.textContent   = d.vin ? 'VIN ' + d.vin : 'VIN ---';
        diagGrid.innerHTML = '';
        DIAG_FIELDS.forEach((f) => {
            const stat = d.stats && d.stats[f.key] || { label: 'unbekannt' };
            const cls  = classForValue(stat.label, stat.value);
            const val  = stat.value != null ? Math.round(stat.value) + '%' : stat.label;
            const pct  = stat.value != null ? stat.value : (cls === 'ok' ? 80 : cls === 'warn' ? 50 : 25);
            const html = `
                <div class="gauge ${cls}">
                    <div class="lbl">${f.label}</div>
                    <div class="val">${val}</div>
                    <div class="bar"><span style="width:${pct}%"></span></div>
                </div>`;
            diagGrid.insertAdjacentHTML('beforeend', html);
        });

        dtcList.innerHTML = '';
        (d.dtc || []).forEach((c) => {
            const li = document.createElement('li');
            li.textContent = c;
            dtcList.appendChild(li);
        });
        if (!(d.dtc || []).length) {
            dtcList.innerHTML = '<li style="border-left-color:var(--ok);background:#0f1a13;color:var(--ok)">Keine Fehlercodes</li>';
        }

        const svcAgo = d.last_service ? Math.floor((Date.now()/1000 - d.last_service) / 3600) : null;
        svcInfo.innerHTML = svcAgo != null
            ? `Letzter Service vor <b>${svcAgo}</b> Stunden`
            : 'Kein Service dokumentiert.';
    }

    function renderScan() {
        const s = STATE.scan || {};
        tblInstalled.innerHTML = '';
        (s.installed || []).forEach((r) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${r.slot}</td><td>${r.part.item}</td><td>${Math.floor(r.part.condition || 100)}%</td>`;
            tblInstalled.appendChild(tr);
        });
        if (!(s.installed || []).length) tblInstalled.innerHTML = '<tr><td colspan="3" style="color:var(--muted)">Keine Einträge.</td></tr>';

        tblMissing.innerHTML = '';
        (s.missing || []).forEach((r) => {
            const opts = (r.options || []).map(o => o.label).join(', ') || '–';
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${r.slot}</td><td>${opts}</td>`;
            tblMissing.appendChild(tr);
        });

    }

    const RANK_LABEL = { 0: 'Lehrling', 1: 'Geselle', 2: 'Meister' };
    const SPEC_LABEL = {
        engine: 'Motor', brakes: 'Bremsen', paint: 'Lack',
        electrics: 'Elektrik', chassis: 'Fahrwerk',
    };

    function renderPerson() {
        const p = STATE.person || {};
        const me = STATE.me || {};
        if (personName) personName.textContent = me.charname || me.identifier || '—';
        const rank = (typeof p.rank === 'number') ? p.rank : 0;
        if (personRank) personRank.textContent = RANK_LABEL[rank] || 'Lehrling';
        const lvl = (me.skill && me.skill.level) || (p.level || 0);
        const xp  = (me.skill && me.skill.xp) || (p.xp || 0);
        const next = Math.max(100, (lvl + 1) * 200);
        if (personXpFill) personXpFill.style.width = Math.min(100, Math.round(xp / next * 100)) + '%';
        if (personXpLabel) personXpLabel.textContent = `Lv ${lvl} · XP ${xp} / ${next}`;
        if (specGrid) {
            specGrid.innerHTML = '';
            const specs = p.specs || {};
            for (const k of Object.keys(SPEC_LABEL)) {
                const score = specs[k] || 0;
                const div = document.createElement('div');
                div.className = 'spec';
                div.innerHTML = `<div class="spec-lbl">${SPEC_LABEL[k]}</div>
                                 <div class="spec-score">${score}</div>
                                 <div class="spec-bar"><span style="width:${Math.min(100, score)}%"></span></div>`;
                specGrid.appendChild(div);
            }
        }
        if (certList) {
            certList.innerHTML = '';
            for (const c of (p.certs || [])) {
                const li = document.createElement('li');
                const ts = c.issued_at ? new Date(c.issued_at * 1000).toLocaleDateString() : '';
                li.innerHTML = `<b>${c.name || c.kind || 'Zertifikat'}</b><span>${ts}</span>`;
                certList.appendChild(li);
            }
            if (!(p.certs || []).length) certList.innerHTML = '<li style="color:var(--muted)">Noch keine Zertifikate.</li>';
        }
        if (tblPortfolio) {
            tblPortfolio.innerHTML = '';
            for (const r of (p.portfolio || [])) {
                const tr = document.createElement('tr');
                const ts = new Date((r.timestamp || 0) * 1000).toLocaleString();
                tr.innerHTML = `<td>${ts}</td><td>${r.action || ''}</td><td>${r.plate || ''}</td>`;
                tblPortfolio.appendChild(tr);
            }
            if (!(p.portfolio || []).length) tblPortfolio.innerHTML = '<tr><td colspan="3" style="color:var(--muted)">Noch keine Eintraege.</td></tr>';
        }
    }

    function renderHistory() {
        tblHistory.innerHTML = '';
        (STATE.history || []).forEach((r) => {
            const tr = document.createElement('tr');
            const ts = new Date((r.timestamp || 0) * 1000).toLocaleString();
            tr.innerHTML = `<td>${ts}</td><td>${r.action}</td><td>${r.charname || ''}</td>`;
            tblHistory.appendChild(tr);
        });
        if (!(STATE.history || []).length) tblHistory.innerHTML = '<tr><td colspan="3" style="color:var(--muted)">Keine Einträge.</td></tr>';
    }

    function renderMe() {
        const me = STATE.me || {};
        meEl.textContent = (me.charname || '')
            + (me.skill ? `  •  Lvl ${me.skill.level} (${me.skill.xp} XP)` : '');
        modeEl.textContent = me.isAdmin ? 'ADMIN VIEW'
            : me.isMech ? 'MECHANIKER'
            : 'FAHRER';
    }

    function switchTab(name) {
        tabsBtns.forEach(b => b.classList.toggle('active', b.dataset.tab === name));
        tabs.forEach(t => t.classList.toggle('active', t.id === 'tab-' + name));
    }

    tabsBtns.forEach((b) => b.addEventListener('click', () => switchTab(b.dataset.tab)));

    // --- Dark/Light-Mode (Batch 13) -------------------------------------
    const THEME_KEY = 'clp_realtuner_theme';
    function applyTheme(theme) {
        const t = theme === 'light' ? 'light' : 'dark';
        document.documentElement.setAttribute('data-theme', t);
        try { localStorage.setItem(THEME_KEY, t); } catch (_) { /* NUI kann LS blocken */ }
        document.querySelectorAll('.theme-toggle').forEach((btn) => {
            btn.textContent = t === 'light' ? 'Dark-Mode' : 'Light-Mode';
            btn.setAttribute('aria-pressed', t === 'light' ? 'true' : 'false');
        });
    }
    (function mountThemeToggle() {
        let saved = 'dark';
        try { saved = localStorage.getItem(THEME_KEY) || 'dark'; } catch (_) {}
        applyTheme(saved);
        const meta = document.querySelector('#app .bar .meta');
        if (meta && !meta.querySelector('.theme-toggle')) {
            const btn = document.createElement('button');
            btn.className = 'theme-toggle';
            btn.type = 'button';
            btn.textContent = saved === 'light' ? 'Dark-Mode' : 'Light-Mode';
            btn.addEventListener('click', () => {
                const next = (document.documentElement.getAttribute('data-theme') === 'light') ? 'dark' : 'light';
                applyTheme(next);
            });
            meta.insertBefore(btn, meta.firstChild);
        }
    })();

    btnClose.addEventListener('click', () => post('close', {}));
    btnRescan.addEventListener('click', async () => {
        const r = await post('scan', {});
        if (r && r.scan) { STATE.scan = r.scan; renderScan(); }
    });

    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') post('close', {});
    });

    window.addEventListener('message', (event) => {
        const msg = event.data || {};
        if (msg.action === 'open') {
            STATE = msg.data || {};
            app.classList.remove('hidden');
            switchTab(STATE.tab || 'diag');
            renderMe();
            renderDiag();
            renderScan();
            renderHistory();
            renderPerson();
        } else if (msg.action === 'close') {
            app.classList.add('hidden');
            STATE = {};
        }
    });
})();
