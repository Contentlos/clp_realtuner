/* =============================================================================
 *  clp_realtuner - Admin Panel
 * ========================================================================== */
(function () {
    'use strict';

    const root = document.getElementById('admin');
    const tabsBtns = document.querySelectorAll('#admin .tabs button[data-atab]');
    const tabs = document.querySelectorAll('#admin .atab');
    const btnClose = document.getElementById('adm-close');

    let SNAP = null;
    let SELECTED_CONFIG_PATH = null;
    let SELECTED_PART = null;
    let SELECTED_VEHICLE = null;

    function post(name, data) {
        const url = `https://${window.GetParentResourceName ? window.GetParentResourceName() : 'clp_realtuner'}/${name}`;
        return fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data || {})
        }).then((r) => r.json()).catch(() => ({}));
    }

    // --- Tabs -----------------------------------------------------------------
    function switchTab(name) {
        tabsBtns.forEach(b => b.classList.toggle('active', b.dataset.atab === name));
        tabs.forEach(t => t.classList.toggle('active', t.id === 'atab-' + name));
        if (name === 'vehicles') loadVehicles();
        if (name === 'logs')     loadLogs();
        if (name === 'skills')   loadSkills();
        if (name === 'locations') renderLocations();
    }
    tabsBtns.forEach((b) => b.addEventListener('click', () => switchTab(b.dataset.atab)));
    btnClose.addEventListener('click', () => post('admin:close', {}));
    window.addEventListener('keydown', (e) => { if (e.key === 'Escape') post('admin:close', {}); });

    // --- Config tree ----------------------------------------------------------
    function renderConfigTree() {
        const host = document.getElementById('config-tree');
        host.innerHTML = '';
        if (!SNAP || !SNAP.config) return;
        renderNode(host, SNAP.config, []);
    }
    function renderNode(host, value, path) {
        if (Array.isArray(value)) {
            value.forEach((v, i) => renderNode(host, v, path.concat(String(i))));
            return;
        }
        if (typeof value === 'object' && value !== null) {
            if (path.length > 0) {
                const group = document.createElement('div');
                group.className = 'node';
                group.innerHTML = `<span class="group">${path.join('.')}</span>`;
                host.appendChild(group);
            }
            Object.keys(value).forEach((k) => renderNode(host, value[k], path.concat(k)));
            return;
        }
        const node = document.createElement('div');
        node.className = 'node';
        const keyPath = path.join('.');
        node.innerHTML = `<span class="key">${keyPath}</span><span class="val">${formatValue(value)}</span>`;
        node.addEventListener('click', () => {
            document.querySelectorAll('.tree .node.selected').forEach(n => n.classList.remove('selected'));
            node.classList.add('selected');
            SELECTED_CONFIG_PATH = keyPath;
            openConfigEditor(keyPath, value);
        });
        host.appendChild(node);
    }
    function formatValue(v) {
        if (typeof v === 'function') return 'ƒ';
        if (typeof v === 'string')   return JSON.stringify(v);
        return String(v);
    }

    function openConfigEditor(keyPath, value) {
        const host = document.getElementById('config-edit');
        const t = typeof value;
        const isBool = t === 'boolean';
        const isNum  = t === 'number';
        const isStr  = t === 'string';
        const inputHtml = isBool
            ? `<label class="toggle"><input type="checkbox" id="edit-val" ${value ? 'checked' : ''}/> ${keyPath}</label>`
            : isNum
                ? `<label><span>${keyPath}</span><input type="number" step="any" id="edit-val" value="${value}"/></label>`
                : isStr
                    ? `<label><span>${keyPath}</span><input type="text" id="edit-val" value="${value.replace(/"/g,'&quot;')}"/></label>`
                    : `<label><span>${keyPath}</span><textarea id="edit-val">${JSON.stringify(value, null, 2)}</textarea></label>`;
        host.innerHTML = `
            ${inputHtml}
            <div class="row">
                <button class="primary" id="edit-save">Speichern</button>
                <button class="ghost" id="edit-cancel">Abbrechen</button>
            </div>
            <small style="color:var(--muted)">Syncronisiert live an alle Clients, persistent in data/runtime.json.</small>
        `;
        document.getElementById('edit-cancel').onclick = () => host.innerHTML = '';
        document.getElementById('edit-save').onclick = async () => {
            const el = document.getElementById('edit-val');
            let v;
            if (isBool) v = el.checked;
            else if (isNum) v = Number(el.value);
            else if (isStr) v = el.value;
            else {
                try { v = JSON.parse(el.value); } catch (e) { alert('Ungültiges JSON'); return; }
            }
            const r = await post('admin:setConfig', { keyPath, value: v });
            if (r && r.ok) { await loadSnapshot(); renderConfigTree(); host.innerHTML = ''; }
        };
    }

    // --- Parts ----------------------------------------------------------------
    function renderPartsList() {
        const tbody = document.querySelector('#parts-list tbody');
        tbody.innerHTML = '';
        const q = (document.getElementById('parts-search').value || '').toLowerCase();
        const parts = SNAP && SNAP.parts || {};
        Object.keys(parts).sort().forEach((item) => {
            const p = parts[item];
            const hay = (item + ' ' + (p.slot || '') + ' ' + (p.category || '')).toLowerCase();
            if (q && !hay.includes(q)) return;
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${item}</td><td>${p.slot || ''}</td><td><span class="pill q${p.quality||2}">${p.quality}</span></td><td>${p.category || ''}</td>`;
            tr.onclick = () => {
                document.querySelectorAll('#parts-list tr.selected').forEach(x => x.classList.remove('selected'));
                tr.classList.add('selected');
                openPartEditor(item, p);
            };
            tbody.appendChild(tr);
        });
    }
    function openPartEditor(item, p) {
        SELECTED_PART = item;
        const host = document.getElementById('parts-editor');
        host.innerHTML = `
            <label><span>item</span><input id="p-item" type="text" value="${item}" ${p ? 'readonly' : ''}/></label>
            <label><span>label</span><input id="p-label" type="text" value="${(p && p.label) || ''}"/></label>
            <label><span>category</span><input id="p-category" type="text" value="${(p && p.category) || ''}"/></label>
            <label><span>slot</span><input id="p-slot" type="text" value="${(p && p.slot) || ''}"/></label>
            <label><span>modType</span><input id="p-modType" type="number" value="${(p && p.modType) != null ? p.modType : -1}"/></label>
            <label><span>modIndex</span><input id="p-modIndex" type="number" value="${(p && p.modIndex) != null ? p.modIndex : -1}"/></label>
            <label><span>quality (1-5)</span><input id="p-quality" type="number" min="1" max="5" value="${(p && p.quality) || 3}"/></label>
            <label><span>installTime ms</span><input id="p-installTime" type="number" value="${(p && p.installTime) || 8000}"/></label>
            <label><span>failChance 0..1</span><input id="p-failChance" type="number" step="0.01" value="${(p && p.failChance) != null ? p.failChance : 0.05}"/></label>
            <label><span>wearMult</span><input id="p-wearMult" type="number" step="0.05" value="${(p && p.wearMult) || 1.0}"/></label>
            <label><span>tuning (JSON)</span><textarea id="p-tuning">${JSON.stringify((p && p.tuning) || {}, null, 2)}</textarea></label>
            <label><span>health (JSON)</span><textarea id="p-health">${JSON.stringify((p && p.health) || null, null, 2)}</textarea></label>
            <div class="row">
                <button class="primary" id="p-save">Speichern</button>
                <button class="danger" id="p-delete">Löschen</button>
            </div>
        `;
        document.getElementById('p-save').onclick = async () => {
            const def = {
                item: document.getElementById('p-item').value.trim(),
                label: document.getElementById('p-label').value,
                category: document.getElementById('p-category').value,
                slot: document.getElementById('p-slot').value,
                modType: Number(document.getElementById('p-modType').value),
                modIndex: Number(document.getElementById('p-modIndex').value),
                quality: Number(document.getElementById('p-quality').value),
                installTime: Number(document.getElementById('p-installTime').value),
                failChance: Number(document.getElementById('p-failChance').value),
                wearMult: Number(document.getElementById('p-wearMult').value),
                tuning: safeParse(document.getElementById('p-tuning').value, {}),
                health: safeParse(document.getElementById('p-health').value, null),
            };
            const r = await post('admin:setPart', { item: def.item, def });
            if (r && r.ok) { await loadSnapshot(); renderPartsList(); }
        };
        document.getElementById('p-delete').onclick = async () => {
            if (!confirm('Teil wirklich löschen?')) return;
            const r = await post('admin:setPart', { item, def: null });
            if (r && r.ok) { await loadSnapshot(); renderPartsList(); host.innerHTML = ''; }
        };
    }
    function safeParse(s, fallback) {
        if (!s || !s.trim()) return fallback;
        try { return JSON.parse(s); } catch (e) { return fallback; }
    }
    document.getElementById('parts-search').addEventListener('input', renderPartsList);
    document.getElementById('parts-new').addEventListener('click', () => openPartEditor('', null));

    // --- Vehicles -------------------------------------------------------------
    async function loadVehicles() {
        const search = document.getElementById('veh-search').value || '';
        const r = await post('admin:listVehicles', { search, limit: 200, offset: 0 });
        const rows = r && r.rows || [];
        const tbody = document.querySelector('#veh-list tbody');
        tbody.innerHTML = '';
        rows.forEach(v => {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${v.plate}</td><td class="mono" style="font-family:var(--mono)">${v.vin||''}</td><td>${v.model||''}</td>
                <td>${Math.round(v.engine_health)}</td><td>${Math.round(v.transmission_health)}</td>
                <td>${Math.round(v.brake_health)}</td><td>${Math.round(v.turbo_health)}</td><td>${Math.round(v.suspension_health)}</td>`;
            tr.onclick = () => openVehicleDetail(v.plate);
            tbody.appendChild(tr);
        });
    }
    async function openVehicleDetail(plate) {
        SELECTED_VEHICLE = plate;
        const r = await post('admin:getVehicle', { plate });
        const rec = r && r.record || {};
        const host = document.getElementById('veh-detail');
        host.innerHTML = `
            <label><span>VIN</span><input type="text" value="${rec.vin||''}" readonly/></label>
            <label><span>engine_health</span><input type="number" step="0.1" id="vd-engine" value="${rec.engine_health||0}"/></label>
            <label><span>transmission</span><input type="number" step="0.1" id="vd-trn" value="${rec.transmission_health||0}"/></label>
            <label><span>brake_health</span><input type="number" step="0.1" id="vd-brk" value="${rec.brake_health||0}"/></label>
            <label><span>turbo_health</span><input type="number" step="0.1" id="vd-trb" value="${rec.turbo_health||0}"/></label>
            <label><span>suspension</span><input type="number" step="0.1" id="vd-sus" value="${rec.suspension_health||0}"/></label>
            <label><span>paint_quality</span><input type="number" step="0.1" id="vd-paint" value="${rec.paint_quality||0}"/></label>
            <label><span>installed_parts</span><textarea id="vd-parts">${JSON.stringify(rec.installed_parts||{}, null, 2)}</textarea></label>
            <label><span>tuning_data</span><textarea id="vd-tuning">${JSON.stringify(rec.tuning_data||{}, null, 2)}</textarea></label>
            <label><span>ecu_state</span><textarea id="vd-ecu">${JSON.stringify(rec.ecu_state||{}, null, 2)}</textarea></label>
            <div class="row">
                <button class="primary" id="vd-save">Speichern</button>
                <button class="danger" id="vd-reset">Reset</button>
            </div>
        `;
        document.getElementById('vd-save').onclick = async () => {
            const patch = {
                engine_health: Number(document.getElementById('vd-engine').value),
                transmission_health: Number(document.getElementById('vd-trn').value),
                brake_health: Number(document.getElementById('vd-brk').value),
                turbo_health: Number(document.getElementById('vd-trb').value),
                suspension_health: Number(document.getElementById('vd-sus').value),
                paint_quality: Number(document.getElementById('vd-paint').value),
                installed_parts: safeParse(document.getElementById('vd-parts').value, {}),
                tuning_data: safeParse(document.getElementById('vd-tuning').value, {}),
                ecu_state: safeParse(document.getElementById('vd-ecu').value, {}),
            };
            const r2 = await post('admin:updateVehicle', { plate, patch });
            if (r2 && r2.ok) { loadVehicles(); openVehicleDetail(plate); }
        };
        document.getElementById('vd-reset').onclick = async () => {
            if (!confirm('Fahrzeug komplett zurücksetzen?')) return;
            const r2 = await post('admin:resetVehicle', { plate });
            if (r2 && r2.ok) { loadVehicles(); openVehicleDetail(plate); }
        };
    }
    document.getElementById('veh-refresh').addEventListener('click', loadVehicles);

    // --- Logs -----------------------------------------------------------------
    async function loadLogs() {
        const filter = {
            plate: document.getElementById('log-plate').value || '',
            identifier: document.getElementById('log-id').value || '',
            action: document.getElementById('log-action').value || '',
            limit: 300,
        };
        const r = await post('admin:logs', filter);
        const rows = r && r.rows || [];
        const tbody = document.querySelector('#log-list tbody');
        tbody.innerHTML = '';
        rows.forEach(l => {
            const tr = document.createElement('tr');
            const ts = new Date((l.timestamp || 0) * 1000).toLocaleString();
            tr.innerHTML = `<td>${ts}</td><td>${l.charname||''}</td><td>${l.action}</td><td>${l.plate||''}</td><td style="font-family:var(--mono);font-size:11px;max-width:380px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${l.detail||''}</td>`;
            tbody.appendChild(tr);
        });
    }
    document.getElementById('log-refresh').addEventListener('click', loadLogs);

    // --- Skills ---------------------------------------------------------------
    async function loadSkills() {
        const search = document.getElementById('skill-search').value || '';
        const r = await post('admin:listSkills', { search });
        const rows = r && r.rows || [];
        const tbody = document.querySelector('#skill-list tbody');
        tbody.innerHTML = '';
        rows.forEach(s => {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${s.identifier}</td><td>${s.level}</td><td>${s.xp}</td><td>${s.repairs}</td><td>${s.installs}</td>
                <td><button class="ghost" data-id="${s.identifier}" data-level="${s.level}" data-xp="${s.xp}">Bearbeiten</button></td>`;
            tbody.appendChild(tr);
        });
        tbody.querySelectorAll('button').forEach(btn => btn.addEventListener('click', async () => {
            const id = btn.dataset.id;
            const newLevel = prompt('Neues Level:', btn.dataset.level);
            if (newLevel === null) return;
            const newXp = prompt('Neues XP:', btn.dataset.xp);
            if (newXp === null) return;
            await post('admin:setSkill', { identifier: id, level: Number(newLevel), xp: Number(newXp) });
            loadSkills();
        }));
    }
    document.getElementById('skill-refresh').addEventListener('click', loadSkills);

    // --- Locations ------------------------------------------------------------
    function renderLocations() {
        const tbody = document.querySelector('#booths-list tbody');
        tbody.innerHTML = '';
        const list = (SNAP && SNAP.locations && SNAP.locations.paintBooths) || [];
        list.forEach((b, i) => {
            const tr = document.createElement('tr');
            tr.innerHTML = `<td>${i+1}</td>
                <td class="mono" style="font-family:var(--mono)">${b.coords && (b.coords.x||b.coords[1]||'').toFixed ? b.coords.x.toFixed(2)+', '+b.coords.y.toFixed(2)+', '+b.coords.z.toFixed(2) : JSON.stringify(b.coords)}</td>
                <td>${Number(b.heading||0).toFixed(1)}</td>
                <td>${b.radius||3}</td>
                <td><button class="danger" data-idx="${i+1}">Löschen</button></td>`;
            tbody.appendChild(tr);
        });
        tbody.querySelectorAll('button').forEach(btn => btn.addEventListener('click', async () => {
            if (!confirm('Paint-Booth entfernen?')) return;
            await post('admin:removePaintBooth', { index: Number(btn.dataset.idx) });
            await loadSnapshot();
            renderLocations();
        }));
    }
    document.getElementById('booth-here').addEventListener('click', async () => {
        const radius = prompt('Radius (m):', '3.0');
        const r = await post('admin:addPaintBoothHere', { radius: Number(radius) || 3.0 });
        if (r && r.ok) { await loadSnapshot(); renderLocations(); }
    });

    // --- Snapshot -------------------------------------------------------------
    async function loadSnapshot() {
        const r = await post('admin:snapshot', {});
        if (r && r.snapshot) SNAP = r.snapshot;
        renderConfigTree();
        renderPartsList();
        renderLocations();
    }

    // --- Message handler ------------------------------------------------------
    window.addEventListener('message', (event) => {
        const msg = event.data || {};
        if (msg.action === 'adminOpen') {
            SNAP = msg.data && msg.data.snapshot || null;
            root.classList.remove('hidden');
            switchTab('config');
            renderConfigTree();
            renderPartsList();
        } else if (msg.action === 'adminClose') {
            root.classList.add('hidden');
            SNAP = null;
        }
    });
})();
