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
        dyno: document.getElementById('diag-dyno'),
        thermal: document.getElementById('diag-thermal'),
        damage: document.getElementById('diag-damage'),
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
            else if (which === 'dyno') post('dyno:close', {});
            else if (which === 'thermal') post('thermal:close', {});
            else if (which === 'damage') post('damage3d:close', {});
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
        else if (panels.dyno && !panels.dyno.classList.contains('hidden')) { hideAll(); post('dyno:close', {}); }
        else if (panels.thermal && !panels.thermal.classList.contains('hidden')) { hideAll(); post('thermal:close', {}); }
        else if (panels.damage && !panels.damage.classList.contains('hidden')) { hideAll(); post('damage3d:close', {}); }
    });

    // Dyno Rendering
    function renderDyno(d) {
        setId('dyno-plate', d.plate || '—');
        setId('dyno-model', d.model || '—');
        setId('dyno-hp', Math.round(d.peakHP || 0));
        setId('dyno-torque', Math.round(d.peakTorque || 0) + ' Nm');
        setId('dyno-t100', d.t0to100 > 0 ? d.t0to100.toFixed(2) + ' s' : '–');
        setId('dyno-t200', d.t0to200 > 0 ? d.t0to200.toFixed(2) + ' s' : '–');
        const qm = d.quarterMile || {};
        setId('dyno-qm', qm.time > 0 ? qm.time.toFixed(2) + ' s (' + qm.dist + 'm)' : '–');

        const canvas = document.getElementById('dyno-chart');
        if (!canvas || !canvas.getContext) return;
        const ctx = canvas.getContext('2d');
        const w = canvas.width, h = canvas.height;
        ctx.clearRect(0, 0, w, h);
        // grid
        ctx.strokeStyle = '#1d2633';
        ctx.lineWidth = 1;
        for (let x = 0; x <= w; x += 80) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke(); }
        for (let y = 0; y <= h; y += 40) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke(); }
        // axes
        ctx.strokeStyle = '#495266'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(40, 20); ctx.lineTo(40, h - 30); ctx.lineTo(w - 20, h - 30); ctx.stroke();
        const rpm = d.rpmCurve || [], hp = d.hpCurve || [];
        if (rpm.length === 0) return;
        const rpmMax = Math.max.apply(null, rpm) || 8000;
        const hpMax = Math.max.apply(null, hp.concat([100])) * 1.1;
        // HP line
        ctx.strokeStyle = '#4cff9a'; ctx.lineWidth = 3;
        ctx.beginPath();
        for (let i = 0; i < rpm.length; i++) {
            const x = 40 + (rpm[i] / rpmMax) * (w - 60);
            const y = (h - 30) - (hp[i] / hpMax) * (h - 50);
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.stroke();
        // labels
        ctx.fillStyle = '#8db9ff'; ctx.font = '11px Consolas, monospace';
        ctx.fillText('HP', 8, 16);
        ctx.fillText('RPM →', w - 55, h - 10);
        ctx.fillStyle = '#7e8899';
        for (let i = 0; i <= 4; i++) {
            const r = Math.round((rpmMax / 4) * i);
            ctx.fillText(r, 40 + (i / 4) * (w - 60) - 10, h - 14);
            const p = Math.round((hpMax / 4) * i);
            ctx.fillText(p, 6, (h - 30) - (i / 4) * (h - 50) + 4);
        }
    }

    // Thermal
    function renderThermal(d) {
        setId('therm-plate', d.plate || '—');
        const alert = document.getElementById('therm-alert');
        if (alert) alert.classList.toggle('hidden', !d.critical);
        const host = document.getElementById('therm-zones');
        if (!host) return;
        host.innerHTML = '';
        (d.zones || []).forEach(z => {
            const row = document.createElement('div');
            row.className = 'therm-zone';
            const pct = Math.max(0, Math.min(100, (z.temp - 20) / 2.8));
            const col = thermalColor(z.temp);
            row.innerHTML = '<label>' + z.label + '</label>' +
                '<div class="therm-bar"><div style="width:' + pct + '%;background:' + col + ';"></div></div>' +
                '<b>' + z.temp + '°C</b>';
            host.appendChild(row);
        });
    }
    function thermalColor(t) {
        if (t < 70) return '#3a9dff';
        if (t < 95) return '#4cff9a';
        if (t < 110) return '#ffd24c';
        if (t < 130) return '#ff954c';
        return '#ff4c4c';
    }

    // Damage 3D
    function renderDamage(d) {
        setId('dmg-plate', d.plate || '—');
        setId('dmg-model', d.model || '—');
        const list = document.getElementById('dmg-list');
        list.innerHTML = '';
        (d.components || []).forEach(c => {
            const hp = Math.max(0, Math.min(100, c.hp));
            const zone = document.querySelector('#dmg-svg [data-comp="' + c.id + '"]');
            if (zone) {
                zone.setAttribute('fill', dmgColor(hp));
                zone.setAttribute('data-label', c.label + ' ' + Math.round(hp) + '%');
            }
            const row = document.createElement('div');
            row.className = 'dmg-row';
            row.innerHTML = '<label>' + c.label + '</label>' +
                '<div class="bar"><div style="width:' + hp + '%;background:' + dmgColor(hp) + ';"></div></div>' +
                '<b>' + Math.round(hp) + '%</b>';
            list.appendChild(row);
        });
    }
    function dmgColor(hp) {
        if (hp > 85) return '#4cff9a';
        if (hp > 60) return '#8fce5b';
        if (hp > 35) return '#ffd24c';
        if (hp > 15) return '#ff954c';
        return '#ff4c4c';
    }

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
        } else if (m.action === 'dyno:start') {
            setId('dyno-plate', d.plate || '—');
            setId('dyno-model', '');
            show('dyno');
        } else if (m.action === 'dyno:result') {
            renderDyno(d);
            show('dyno');
        } else if (m.action === 'thermal:open') {
            renderThermal(d);
            show('thermal');
        } else if (m.action === 'damage3d:open') {
            renderDamage(d);
            show('damage');
        }
    });
})();
