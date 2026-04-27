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
    const tblUpgrade   = document.querySelector('#parts-upgrade tbody');
    const tblHistory   = document.querySelector('#history-table tbody');
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

        tblUpgrade.innerHTML = '';
        (s.upgrades || []).forEach((r) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${r.slot}</td><td>${r.best.label}</td><td>Q${r.best.quality}</td>`;
            tblUpgrade.appendChild(tr);
        });
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
        } else if (msg.action === 'close') {
            app.classList.add('hidden');
            STATE = {};
        }
    });
})();
