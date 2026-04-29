/* =========================================================================
 *  clp_realtuner - 3D Inspector NUI (Batch 14a)
 *  Scoped IIFE; rendert die Sidebar, sendet Preview-Events an Lua,
 *  Confirm/Cancel ueber inspector:confirm bzw. inspector:cancel callbacks.
 * ========================================================================= */
(function () {
    'use strict';

    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'clp_realtuner';
    const root = document.getElementById('inspector');
    if (!root) return;

    const elTitle  = root.querySelector('.ins-title');
    const elPlate  = root.querySelector('.ins-plate');
    const elBody   = root.querySelector('.ins-body');
    const tabs     = root.querySelectorAll('.ins-tabs button');

    // Helper ---------------------------------------------------------------
    function post(name, body) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(body || {}),
        }).catch(() => null);
    }

    function clearSection(id) {
        const sec = root.querySelector(`#ins-sec-${id}`);
        if (sec) sec.innerHTML = '';
        return sec;
    }

    function el(tag, props, children) {
        const e = document.createElement(tag);
        if (props) {
            for (const k of Object.keys(props)) {
                if (k === 'class') e.className = props[k];
                else if (k === 'text') e.textContent = props[k];
                else if (k === 'html') e.innerHTML = props[k];
                else if (k.startsWith('on') && typeof props[k] === 'function') {
                    e.addEventListener(k.slice(2).toLowerCase(), props[k]);
                } else e.setAttribute(k, props[k]);
            }
        }
        if (children) for (const c of children) if (c) e.appendChild(c);
        return e;
    }

    // Renderers ------------------------------------------------------------
    function renderModSlot(slot) {
        const wrap = el('div', { class: 'ins-slot' });
        wrap.appendChild(el('div', { class: 'slot-head' }, [
            el('span', { class: 'slot-name', text: slot.label }),
            el('span', { class: 'slot-cat',  text: slot.category || '' }),
        ]));
        const pills = el('div', { class: 'slot-pills' });
        for (const opt of slot.options) {
            const b = el('button', { type: 'button', text: opt.label });
            if (opt.idx === slot.current) b.classList.add('active');
            b.addEventListener('click', () => {
                pills.querySelectorAll('button').forEach((x) => x.classList.remove('active'));
                b.classList.add('active');
                post('inspector:setMod', { modType: slot.modType, idx: opt.idx });
            });
            pills.appendChild(b);
        }
        wrap.appendChild(pills);
        return wrap;
    }

    function renderToggle(t) {
        const wrap = el('div', { class: 'ins-toggle' + (t.on ? ' on' : '') });
        wrap.appendChild(el('div', { class: 'lbl', text: t.label }));
        const sw = el('div', { class: 'sw' });
        sw.addEventListener('click', () => {
            const next = !wrap.classList.contains('on');
            wrap.classList.toggle('on', next);
            post('inspector:setToggle', { modType: t.modType, on: next });
        });
        wrap.appendChild(sw);
        return wrap;
    }

    function renderWheelTypes(types, current) {
        const wrap = el('div', { class: 'ins-slot' });
        wrap.appendChild(el('div', { class: 'slot-head' }, [
            el('span', { class: 'slot-name', text: 'Reifen-Typ (Wheel-Style)' }),
            el('span', { class: 'slot-cat',  text: 'wheels' }),
        ]));
        const pills = el('div', { class: 'slot-pills' });
        for (const t of types) {
            const b = el('button', { type: 'button', text: t.label });
            if (t.id === current) b.classList.add('active');
            b.addEventListener('click', () => {
                pills.querySelectorAll('button').forEach((x) => x.classList.remove('active'));
                b.classList.add('active');
                post('inspector:setWheelType', { id: t.id });
            });
            pills.appendChild(b);
        }
        wrap.appendChild(pills);
        return wrap;
    }

    function renderLivery(count, current) {
        if (!count || count <= 0) return null;
        const wrap = el('div', { class: 'ins-slot' });
        wrap.appendChild(el('div', { class: 'slot-head' }, [
            el('span', { class: 'slot-name', text: 'Lackbild / Livery' }),
            el('span', { class: 'slot-cat',  text: 'paint' }),
        ]));
        const pills = el('div', { class: 'slot-pills' });
        for (let i = -1; i < count; i++) {
            const b = el('button', { type: 'button', text: i < 0 ? 'Original' : `Livery #${i + 1}` });
            if (i === current) b.classList.add('active');
            b.addEventListener('click', () => {
                pills.querySelectorAll('button').forEach((x) => x.classList.remove('active'));
                b.classList.add('active');
                post('inspector:setLivery', { idx: i });
            });
            pills.appendChild(b);
        }
        wrap.appendChild(pills);
        return wrap;
    }

    function renderTint(current) {
        const wrap = el('div', { class: 'ins-slot' });
        wrap.appendChild(el('div', { class: 'slot-head' }, [
            el('span', { class: 'slot-name', text: 'Scheiben-Tönung' }),
            el('span', { class: 'slot-cat',  text: 'paint' }),
        ]));
        const labels = ['Klar', 'Dunkel', 'Schwarz', 'Schwarz Hi', 'Lichtgrau', 'Grün'];
        const pills = el('div', { class: 'slot-pills' });
        labels.forEach((lab, i) => {
            const b = el('button', { type: 'button', text: lab });
            if (i === current) b.classList.add('active');
            b.addEventListener('click', () => {
                pills.querySelectorAll('button').forEach((x) => x.classList.remove('active'));
                b.classList.add('active');
                post('inspector:setTint', { idx: i });
            });
            pills.appendChild(b);
        });
        wrap.appendChild(pills);
        return wrap;
    }

    function renderPaint(kinds, types, current) {
        // GTA Paint-Index 0..159 - wir bieten Hauptauswahl in Pills, Slider fein
        const wrap = el('div', { class: 'ins-slot' });
        wrap.appendChild(el('div', { class: 'slot-head' }, [
            el('span', { class: 'slot-name', text: 'Lackierung' }),
            el('span', { class: 'slot-cat',  text: 'paint' }),
        ]));
        for (const kind of kinds) {
            const sub = el('div', { class: 'slot-pills' });
            sub.style.marginBottom = '6px';
            sub.appendChild(el('span', { class: 'slot-cat', text: kind.label, style: 'flex-basis:100%; margin-bottom:4px;' }));
            for (let i = 0; i < 160; i += 8) { // alle 8 Farben als Pill (20 Stueck)
                const b = el('button', { type: 'button', text: '#' + i });
                if (current && current[kind.id] === i) b.classList.add('active');
                b.addEventListener('click', () => {
                    sub.querySelectorAll('button').forEach((x) => x.classList.remove('active'));
                    b.classList.add('active');
                    post('inspector:setPaint', { kind: kind.id, value: i });
                });
                sub.appendChild(b);
            }
            wrap.appendChild(sub);
        }
        return wrap;
    }

    // Tabs -----------------------------------------------------------------
    function showSection(id) {
        tabs.forEach((t) => t.classList.toggle('active', t.dataset.sec === id));
        root.querySelectorAll('.ins-section').forEach((s) => {
            s.classList.toggle('active', s.id === `ins-sec-${id}`);
        });
    }
    tabs.forEach((t) => t.addEventListener('click', () => showSection(t.dataset.sec)));

    // Open / Close ---------------------------------------------------------
    function open(payload) {
        const slots = payload.slots || {};
        elPlate.textContent = slots.plate || payload.plate || '';
        if (elTitle) elTitle.textContent = '3D-INSPECTOR · ' + ((slots.modelName || payload.modelName || '').toUpperCase());
        const byCat = { body: [], wheels: [], paint: [], interior: [], engine: [] };
        for (const slot of (payload.slots.mods || [])) (byCat[slot.category] || byCat.body).push(slot);
        // Body section
        const sBody = clearSection('body');
        if (byCat.body.length === 0) sBody.appendChild(el('div', { class: 'ins-empty', text: 'Keine Karosserie-Mods für dieses Modell.' }));
        for (const s of byCat.body) sBody.appendChild(renderModSlot(s));
        // Wheels section
        const sWheels = clearSection('wheels');
        for (const s of byCat.wheels) sWheels.appendChild(renderModSlot(s));
        sWheels.appendChild(renderWheelTypes(payload.slots.wheelTypes, payload.slots.currentWheelType));
        // Paint section
        const sPaint = clearSection('paint');
        sPaint.appendChild(renderPaint(payload.slots.paint, payload.slots.paintTypes, payload.slots.currentPaint));
        const liv = renderLivery(payload.slots.liveryCount, payload.slots.currentLivery);
        if (liv) sPaint.appendChild(liv);
        sPaint.appendChild(renderTint(payload.slots.currentTint));
        // Interior section
        const sInt = clearSection('interior');
        if (byCat.interior.length === 0) sInt.appendChild(el('div', { class: 'ins-empty', text: 'Keine Innenraum-Mods.' }));
        for (const s of byCat.interior) sInt.appendChild(renderModSlot(s));
        // Engine section
        const sEng = clearSection('engine');
        if (byCat.engine.length === 0) sEng.appendChild(el('div', { class: 'ins-empty', text: 'Keine Motor-Optik-Mods.' }));
        for (const s of byCat.engine) sEng.appendChild(renderModSlot(s));
        // Performance section (toggles)
        const sPerf = clearSection('perf');
        for (const t of (payload.slots.toggles || [])) sPerf.appendChild(renderToggle(t));
        // Default tab
        showSection('body');
        root.classList.remove('hidden');
    }
    function close() { root.classList.add('hidden'); }

    // Foot buttons + ESC handler
    const btnConfirm = root.querySelector('.confirm');
    const btnCancel  = root.querySelector('.cancel');
    if (btnConfirm) btnConfirm.addEventListener('click', () => post('inspector:confirm', {}));
    if (btnCancel)  btnCancel.addEventListener('click',  () => post('inspector:cancel',  {}));
    document.addEventListener('keydown', (e) => {
        if (root.classList.contains('hidden')) return;
        if (e.key === 'Escape') post('inspector:cancel', {});
        if (e.key === 'Enter')  post('inspector:confirm', {});
    });

    // NUI bus
    window.addEventListener('message', (ev) => {
        const d = ev.data || {};
        if (d.type === 'inspector:open') open(d);
        else if (d.type === 'inspector:close') close();
    });
})();
