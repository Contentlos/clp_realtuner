/* =========================================================================
 *  clp_realtuner - Werkstatt-PC NUI (Batch 14b)
 *  Scoped IIFE; rendert die linke Sidebar + Sektionen anhand des Status,
 *  sendet Aktionen an Lua per fetch.
 * ========================================================================= */
(function () {
    'use strict';

    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'clp_realtuner';
    const root = document.getElementById('wspc');
    if (!root) return;

    function post(name, body) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => null);
    }

    function el(tag, props, children) {
        const e = document.createElement(tag);
        if (props) for (const k of Object.keys(props)) {
            if (k === 'class') e.className = props[k];
            else if (k === 'text') e.textContent = props[k];
            else if (k === 'html') e.innerHTML = props[k];
            else if (k.startsWith('on') && typeof props[k] === 'function') e.addEventListener(k.slice(2).toLowerCase(), props[k]);
            else e.setAttribute(k, props[k]);
        }
        if (children) for (const c of children) if (c) e.appendChild(c);
        return e;
    }

    function fmt(n) { return Number(n || 0).toLocaleString('de-DE'); }
    function clamp(n, lo, hi) { return Math.max(lo, Math.min(hi, n)); }

    // --------- Top-Bar / Sidebar -------------------------------------------
    function buildShell() {
        root.innerHTML = '';
        const frame = el('div', { class: 'pc-frame' });
        const bar = el('div', { class: 'pc-bar' }, [
            el('div', { class: 'pc-brand' }, [
                el('span', { class: 'dot' }),
                el('span', { text: 'WERKSTATT-PC · LS-NET' }),
            ]),
            el('div', { class: 'pc-meta' }, [
                el('span', { id: 'wspc-name', text: '' }),
                el('span', { id: 'wspc-bank', class: 'bank', text: '$ 0' }),
                el('button', { class: 'close', type: 'button', text: '×',
                               onclick: () => post('wspc:close', {}) }),
            ]),
        ]);
        const body = el('div', { class: 'pc-body' });
        const side = el('div', { class: 'pc-side' });
        side.appendChild(el('div', { class: 'side-title', text: 'Navigation' }));
        const tabs = [
            { id: 'orders',   label: 'Bestellungen' },
            { id: 'catalog',  label: 'Katalog' },
            { id: 'parts',    label: 'Lager · Mechanik' },
            { id: 'body',     label: 'Lager · Karosserie' },
            { id: 'paint',    label: 'Lager · Lack' },
            { id: 'fluids',   label: 'Lager · Verbrauch' },
            { id: 'prices',   label: 'Preisliste' },
            { id: 'bank',     label: 'Werkstattkonto' },
        ];
        for (const t of tabs) {
            const b = el('button', { class: 'side-btn', type: 'button', 'data-sec': t.id }, [
                el('span', { class: 'icon', text: '·' }),
                el('span', { text: t.label }),
            ]);
            b.addEventListener('click', () => showSection(t.id));
            side.appendChild(b);
        }
        const main = el('div', { class: 'pc-main', id: 'wspc-main' });
        for (const t of tabs) main.appendChild(el('section', { class: 'pc-section', id: 'wspc-sec-' + t.id }));
        body.appendChild(side); body.appendChild(main);
        frame.appendChild(bar); frame.appendChild(body);
        root.appendChild(frame);
        showSection('orders');
    }

    function showSection(id) {
        root.querySelectorAll('.side-btn').forEach((b) => b.classList.toggle('active', b.dataset.sec === id));
        root.querySelectorAll('.pc-section').forEach((s) => s.classList.toggle('active', s.id === 'wspc-sec-' + id));
    }

    // --------- Section Renderers ------------------------------------------
    function renderOrders(status) {
        const sec = root.querySelector('#wspc-sec-orders'); sec.innerHTML = '';
        sec.appendChild(el('h2', { text: 'Bestellungen' }));
        const panel = el('div', { class: 'panel' });
        if (!status.orders || status.orders.length === 0) {
            panel.appendChild(el('div', { class: 'empty', text: 'Keine Bestellungen.' }));
        } else {
            for (const o of status.orders) {
                const eta = Number(o.delivers_at) - Number(status.now || 0);
                const etaStr = eta > 0
                    ? new Date(eta * 1000).toISOString().substr(11, 8).replace(/^00:/, '')
                    : 'jetzt';
                const row = el('div', { class: 'order' });
                row.appendChild(el('div', {}, [
                    el('div', { class: 'name', text: `${o.amount}× ${o.item}` }),
                    el('div', { class: 'meta', text: `Cat ${o.category} · $${fmt(o.total_cost)} · ETA ${etaStr}` }),
                ]));
                row.appendChild(el('span', { class: 'badge ' + (o.status || 'pending'), text: o.status || 'pending' }));
                row.appendChild(el('span', { class: 'meta',
                    text: o.delivered_at ? ('@' + new Date(o.delivered_at * 1000).toLocaleTimeString('de-DE')) : '' }));
                if (o.status === 'pending') {
                    row.appendChild(el('button', { class: 'btn danger', type: 'button', text: 'Stornieren',
                                                   onclick: () => post('wspc:cancel', { id: o.id }) }));
                } else {
                    row.appendChild(el('span', {}));
                }
                panel.appendChild(row);
            }
        }
        sec.appendChild(panel);
    }

    function renderCatalog(catalog, status) {
        const sec = root.querySelector('#wspc-sec-catalog'); sec.innerHTML = '';
        sec.appendChild(el('h2', { text: 'Katalog · Bestellung' }));
        for (const cat of ['parts','body','paint','fluids']) {
            const list = (catalog && catalog[cat]) || [];
            const usage = sumStock(status.stock && status.stock[cat]);
            const cap   = (status.capacities && status.capacities[cat]) || 0;
            sec.appendChild(el('h3', { text: catLabel(cat) + ` · ${usage}/${cap} belegt` }));
            const grid = el('div', { class: 'catalog' });
            if (list.length === 0) grid.appendChild(el('div', { class: 'empty', text: 'Leer.' }));
            for (const it of list) {
                const card = el('div', { class: 'card' }, [
                    el('div', { class: 'nm', text: it.label }),
                    el('div', { class: 'pr', text: '$ ' + fmt(it.unitCost) + ' · Q' + (it.quality || 1) }),
                ]);
                const amt = el('input', { class: 'input', type: 'number', value: '1', min: '1', max: '50' });
                amt.style.width = '60px';
                const orderBtn = el('button', { class: 'btn primary', type: 'button', text: 'Bestellen' });
                orderBtn.addEventListener('click', () => {
                    const a = clamp(parseInt(amt.value, 10) || 1, 1, 50);
                    post('wspc:order', { item: it.item, amount: a });
                });
                const acts = el('div', { class: 'actions' }, [amt, orderBtn]);
                card.appendChild(acts);
                grid.appendChild(card);
            }
            sec.appendChild(grid);
        }
    }

    function sumStock(arr) {
        if (!Array.isArray(arr)) return 0;
        let s = 0; for (const r of arr) s += Number(r.amount) || 0; return s;
    }

    function catLabel(cat) {
        return ({
            parts:  'Mechanik-Lager',
            body:   'Karosserie-Lager',
            paint:  'Lack-Lager',
            fluids: 'Verbrauchsstoffe',
        })[cat] || cat;
    }

    function renderInventoryTab(cat, status) {
        const sec = root.querySelector('#wspc-sec-' + cat); sec.innerHTML = '';
        const list = (status.stock && status.stock[cat]) || [];
        const cap  = (status.capacities && status.capacities[cat]) || 0;
        const used = sumStock(list);
        sec.appendChild(el('h2', { text: catLabel(cat) }));
        const head = el('div', { class: 'panel' });
        head.appendChild(el('h3', { text: `Belegung: ${used}/${cap}` }));
        const bar = el('div', { class: 'cap-bar' + (used >= cap ? ' full' : '') });
        bar.appendChild(el('span', { style: 'width:' + Math.min(100, Math.round(used / Math.max(1, cap) * 100)) + '%' }));
        head.appendChild(bar);
        sec.appendChild(head);

        const panel = el('div', { class: 'panel' });
        if (list.length === 0) {
            panel.appendChild(el('div', { class: 'empty', text: 'Lager leer. Bestelle im Katalog.' }));
        } else {
            const tbl = el('table', { class: 'data' });
            const thead = el('thead'); const trh = el('tr');
            ['Item', 'Bestand', 'Min', 'Aktion'].forEach((h) => trh.appendChild(el('th', { text: h })));
            thead.appendChild(trh); tbl.appendChild(thead);
            const tbody = el('tbody');
            for (const r of list) {
                const tr = el('tr');
                tr.appendChild(el('td', { class: 'item', text: r.item }));
                const lo = (r.minStock || 0) > 0 && r.amount < r.minStock;
                tr.appendChild(el('td', { class: 'qty' + (lo ? ' low' : ''), text: String(r.amount) }));
                const minIn = el('input', { class: 'input', type: 'number', value: String(r.minStock || 0), min: '0' });
                minIn.style.width = '64px';
                minIn.addEventListener('change', () => post('wspc:setMinStock', {
                    item: r.item, minStock: parseInt(minIn.value, 10) || 0,
                }));
                tr.appendChild(el('td', {}, [minIn]));
                const acts = el('td');
                const takeBtn = el('button', { class: 'btn', type: 'button', text: 'Entnehmen 1',
                    onclick: () => post('wspc:takeStock', { item: r.item, amount: 1 }),
                });
                acts.appendChild(takeBtn); tr.appendChild(acts);
                tbody.appendChild(tr);
            }
            tbl.appendChild(tbody); panel.appendChild(tbl);
        }
        sec.appendChild(panel);
    }

    function renderPrices(status) {
        const sec = root.querySelector('#wspc-sec-prices'); sec.innerHTML = '';
        sec.appendChild(el('h2', { text: 'Preisliste · Services' }));
        const services = ['inspection', 'oil_change', 'tire_change', 'paintjob_basic',
                          'paintjob_metallic', 'paintjob_pearl', 'tune_install',
                          'tune_remove', 'dyno_run', 'tuev'];
        const rec = {}; for (const p of (status.prices || [])) rec[p.service] = p.price;
        const panel = el('div', { class: 'panel' });
        const tbl = el('table', { class: 'data' });
        const thead = el('thead'); const trh = el('tr');
        ['Service', 'Preis ($)', 'Speichern'].forEach((h) => trh.appendChild(el('th', { text: h })));
        thead.appendChild(trh); tbl.appendChild(thead);
        const tbody = el('tbody');
        for (const s of services) {
            const tr = el('tr');
            tr.appendChild(el('td', { class: 'item', text: s }));
            const inp = el('input', { class: 'input', type: 'number', min: '0', value: String(rec[s] || 0) });
            inp.style.width = '90px';
            tr.appendChild(el('td', {}, [inp]));
            const btn = el('button', { class: 'btn', type: 'button', text: 'Setzen',
                onclick: () => post('wspc:setPrice', { service: s, price: parseInt(inp.value, 10) || 0 }),
            });
            tr.appendChild(el('td', {}, [btn]));
            tbody.appendChild(tr);
        }
        tbl.appendChild(tbody); panel.appendChild(tbl);
        sec.appendChild(panel);
    }

    function renderBank(status) {
        const sec = root.querySelector('#wspc-sec-bank'); sec.innerHTML = '';
        sec.appendChild(el('h2', { text: 'Werkstattkonto' }));
        const panel = el('div', { class: 'panel' });
        const bal = el('h3', { text: 'Saldo: $ ' + fmt(status.workshop && status.workshop.bank) });
        panel.appendChild(bal);
        const row = el('div', { class: 'row' });
        for (const op of [{ key: 'depositCash', lbl: 'Bargeld einzahlen', primary: false },
                          { key: 'withdraw',    lbl: 'Auf eigenes Konto auszahlen', primary: true }]) {
            const card = el('div', { class: 'panel' });
            card.appendChild(el('h3', { text: op.lbl }));
            const inp = el('input', { class: 'input', type: 'number', min: '1', value: '1000' });
            const btn = el('button', { class: 'btn ' + (op.primary ? 'primary' : ''), type: 'button', text: 'Ausführen',
                onclick: () => post('wspc:' + op.key, { amount: parseInt(inp.value, 10) || 0 }),
            });
            card.appendChild(inp); card.appendChild(el('div', { style: 'height:8px;' }));
            card.appendChild(btn); row.appendChild(card);
        }
        panel.appendChild(row);
        sec.appendChild(panel);
    }

    // --------- Master render ---------------------------------------------
    function render(status, catalog) {
        if (!status || !status.workshop) return;
        const nameEl = root.querySelector('#wspc-name');
        const bankEl = root.querySelector('#wspc-bank');
        if (nameEl) nameEl.textContent = status.workshop.name + ' (#' + status.workshop.id + ')';
        if (bankEl) bankEl.textContent = '$ ' + fmt(status.workshop.bank);
        renderOrders(status);
        renderCatalog(catalog, status);
        for (const c of ['parts', 'body', 'paint', 'fluids']) renderInventoryTab(c, status);
        renderPrices(status);
        renderBank(status);
    }

    // --------- NUI bus ----------------------------------------------------
    let lastCatalog = {};
    window.addEventListener('message', (ev) => {
        const d = ev.data || {};
        if (d.type === 'wspc:open') {
            buildShell();
            root.classList.remove('hidden');
        } else if (d.type === 'wspc:close') {
            root.classList.add('hidden');
        } else if (d.type === 'wspc:status') {
            if (d.catalog) lastCatalog = d.catalog;
            render(d.status, d.catalog || lastCatalog);
        }
    });

    document.addEventListener('keydown', (e) => {
        if (root.classList.contains('hidden')) return;
        if (e.key === 'Escape') post('wspc:close', {});
    });
})();
