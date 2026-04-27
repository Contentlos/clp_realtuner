// clp_realtuner - Diagnose-Overlays (Batch 2)
(function () {
    'use strict';

    const root = document.getElementById('diag');
    const panels = {
        obd: document.getElementById('diag-obd'),
        endo: document.getElementById('diag-endo'),
        brake: document.getElementById('diag-brake'),
        emissions: document.getElementById('diag-emissions'),
        dtc: document.getElementById('diag-dtc'),
    };

    function setId(id, val) {
        const el = document.getElementById(id);
        if (el) el.textContent = val == null ? '—' : String(val);
    }

    function setBar(id, pct) {
        const el = document.getElementById(id);
        if (el) el.style.width = Math.max(0, Math.min(100, pct)) + '%';
    }

    function show(panel) {
        root.classList.remove('hidden');
        Object.values(panels).forEach(p => p && p.classList.add('hidden'));
        if (panels[panel]) panels[panel].classList.remove('hidden');
    }

    function hideAll() {
        root.classList.add('hidden');
        Object.values(panels).forEach(p => p && p.classList.add('hidden'));
    }

    async function post(name, data) {
        try {
            const r = await fetch('https://' + GetParentResourceName() + '/' + name, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data || {}),
            });
            return await r.json();
        } catch (e) { return null; }
    }

    function GetParentResourceName() {
        return (window.GetParentResourceName && window.GetParentResourceName()) || 'clp_realtuner';
    }

    // Close buttons
    document.addEventListener('click', (e) => {
        const t = e.target;
        if (t && t.classList && t.classList.contains('close')) {
            const which = t.getAttribute('data-close');
            hideAll();
            if (which === 'obd') post('diag:obdClose', {});
            else if (which === 'endo') post('diag:endoscopeClose', {});
            else if (which === 'brake') post('diag:brakeStandClose', {});
            else if (which === 'emissions') post('diag:emissionsClose', {});
            else if (which === 'dtc') post('diag:dtcDeepClose', {});
        }
    });

    window.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape') return;
        if (root.classList.contains('hidden')) return;
        // check which panel is open and close it properly
        if (!panels.obd.classList.contains('hidden')) { hideAll(); post('diag:obdClose', {}); }
        else if (!panels.endo.classList.contains('hidden')) { hideAll(); post('diag:endoscopeClose', {}); }
        else if (!panels.brake.classList.contains('hidden')) { hideAll(); post('diag:brakeStandClose', {}); }
        else if (!panels.emissions.classList.contains('hidden')) { hideAll(); post('diag:emissionsClose', {}); }
        else if (!panels.dtc.classList.contains('hidden')) { hideAll(); post('diag:dtcDeepClose', {}); }
    });

    function renderObdUpdate(d) {
        setId('obd-rpm', d.rpm);
        setBar('obd-rpm-bar', (d.rpmPct || 0) * 100);
        setId('obd-speed', d.speed);
        setId('obd-ct', Math.round(d.coolantTemp || 0) + '°');
        setId('obd-oil', Math.round(d.oilQuality || 0) + '%');
        setId('obd-oilkm', Math.round(d.oilKm || 0));
        setId('obd-batt', Math.round(d.battery || 0) + '%');
        setId('obd-spark', Math.round(d.sparkPlug || 0) + '%');
        setId('obd-bf', Math.round(d.brakeFluid || 0) + '%');
        setId('obd-coolant', Math.round(d.coolant || 0) + '%');
        setId('obd-leak', Math.round(d.fuelLeak || 0));
        setId('obd-rust', Math.round(d.rust || 0) + '%');
        setId('obd-eng', Math.round(d.engineHP || 0) + '%');
        setId('obd-tran', Math.round(d.transmissionHP || 0) + '%');
        setId('obd-brk', Math.round(d.brakeHP || 0) + '%');
        setId('obd-tur', Math.round(d.turboHP || 0) + '%');
        setId('obd-sus', Math.round(d.suspensionHP || 0) + '%');
        setId('obd-tc', d.tcOn ? 'AN' : 'AUS');
        setId('obd-abs', d.absOn ? 'AN' : 'AUS');
        setId('obd-flap', d.flap ? 'OFFEN' : 'ZU');
        setId('obd-map', d.ecuMap || 'stock');

        const ul = document.getElementById('obd-dtc');
        if (ul) {
            ul.innerHTML = '';
            (d.dtc || []).forEach(code => {
                const li = document.createElement('li');
                li.textContent = code;
                ul.appendChild(li);
            });
            if ((d.dtc || []).length === 0) {
                const li = document.createElement('li');
                li.className = 'ok';
                li.textContent = 'Keine Fehlercodes.';
                ul.appendChild(li);
            }
        }
    }

    function renderEndoscope(d) {
        const setBarVal = (bar, val, label) => {
            setBar(bar, val);
            setId(label, Math.round(val) + '%');
        };
        setBarVal('endo-carbon', d.carbon || 0, 'endo-carbon-v');
        setBarVal('endo-sludge', d.oilSludge || 0, 'endo-sludge-v');
        setBarVal('endo-spark', d.sparkPlugWear || 0, 'endo-spark-v');
        setBarVal('endo-turbo', d.turboBlades || 0, 'endo-turbo-v');
        setBarVal('endo-leak', d.leak || 0, 'endo-leak-v');
        setBarVal('endo-coolres', d.coolantResidue || 0, 'endo-coolres-v');
        setBarVal('endo-rust', d.rust || 0, 'endo-rust-v');
    }

    function renderBrake(d) {
        setId('brk-plate', d.plate || '—');
        setId('brk-left', (d.leftKN || 0).toFixed(1) + ' kN');
        setId('brk-right', (d.rightKN || 0).toFixed(1) + ' kN');
        setId('brk-imb', (d.imbalance || 0).toFixed(1) + '%');
        setId('brk-bf', Math.round(d.brakeFluid || 0) + '%');
        setId('brk-grade', d.grade || '—');
        const legal = document.getElementById('brk-legal');
        if (legal) {
            legal.textContent = d.legal ? 'JA – bestanden' : 'NEIN – durchgefallen';
            legal.className = d.legal ? 'ok' : 'fail';
        }
    }

    function renderEmissions(d) {
        setId('em-plate', d.plate || '—');
        setId('em-co', (d.co || 0).toFixed(2) + '%');
        setId('em-hc', (d.hc || 0) + ' ppm');
        setId('em-nox', (d.nox || 0) + ' ppm');
        setId('em-map', d.ecuMap || 'stock');
        const res = document.getElementById('em-result');
        if (res) {
            res.textContent = d.passed ? 'BESTANDEN' : 'DURCHGEFALLEN';
            res.className = d.passed ? 'ok' : 'fail';
        }
        const ul = document.getElementById('em-fails');
        if (ul) {
            ul.innerHTML = '';
            (d.failures || []).forEach(f => {
                const li = document.createElement('li');
                li.textContent = f;
                ul.appendChild(li);
            });
            if ((d.failures || []).length === 0) {
                const li = document.createElement('li');
                li.className = 'ok';
                li.textContent = 'Keine Mängel.';
                ul.appendChild(li);
            }
        }
    }

    function renderDtcDeep(d) {
        setId('dtc-plate', d.plate || '—');
        const ul = document.getElementById('dtc-list');
        if (!ul) return;
        ul.innerHTML = '';
        (d.codes || []).forEach(c => {
            const li = document.createElement('li');
            li.className = 'sev-' + (c.severity || 1);
            li.innerHTML =
                '<div class="dtc-head"><b>' + escapeHtml(c.code) + '</b> · ' + escapeHtml(c.title) + '</div>' +
                '<div class="dtc-body"><div><i>Ursache:</i> ' + escapeHtml(c.cause || '') + '</div>' +
                '<div><i>Fix:</i> ' + escapeHtml(c.fix || '') + '</div></div>';
            ul.appendChild(li);
        });
        if ((d.codes || []).length === 0) {
            const li = document.createElement('li');
            li.className = 'ok';
            li.textContent = 'Keine aktiven Fehlercodes.';
            ul.appendChild(li);
        }
    }

    function escapeHtml(s) {
        return String(s || '').replace(/[&<>"']/g, (c) => ({
            '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
        }[c]));
    }

    window.addEventListener('message', (event) => {
        const m = event.data || {};
        const d = m.data || {};
        if (m.action === 'diag:obdOpen') {
            setId('obd-plate', d.plate || '—');
            setId('obd-model', d.model || '—');
            show('obd');
        } else if (m.action === 'diag:obdUpdate') {
            if (!panels.obd.classList.contains('hidden')) renderObdUpdate(d);
        } else if (m.action === 'diag:obdClose') {
            if (!panels.obd.classList.contains('hidden')) hideAll();
        } else if (m.action === 'diag:endoscopeOpen') {
            setId('endo-plate', d.plate || '—');
            show('endo');
        } else if (m.action === 'diag:endoscopeReport') {
            renderEndoscope(d);
        } else if (m.action === 'diag:endoscopeClose') {
            if (!panels.endo.classList.contains('hidden')) hideAll();
        } else if (m.action === 'diag:brakeStandResult') {
            renderBrake(d);
            show('brake');
        } else if (m.action === 'diag:emissionsResult') {
            renderEmissions(d);
            show('emissions');
        } else if (m.action === 'diag:dtcDeep') {
            renderDtcDeep(d);
            show('dtc');
        }
    });
})();
