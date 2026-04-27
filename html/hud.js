// =============================================================================
//  clp_realtuner - HUD Renderer (NUI)
// =============================================================================
(function () {
    'use strict';
    const hud = document.getElementById('hud');
    if (!hud) return;

    const el = {
        rpm:    document.getElementById('hud-rpm'),
        rpmBar: document.getElementById('hud-rpm-bar'),
        speed:  document.getElementById('hud-speed'),
        gear:   document.getElementById('hud-gear'),
        temp:   document.getElementById('hud-temp'),
        oil:    document.getElementById('hud-oil'),
        boost:  document.getElementById('hud-boost'),
        batt:   document.getElementById('hud-batt'),
        fuel:   document.getElementById('hud-fuel'),
        tc:     document.getElementById('hud-tc'),
        abs:    document.getElementById('hud-abs'),
        flap:   document.getElementById('hud-flap'),
        map:    document.getElementById('hud-map'),
    };

    function show() { hud.classList.remove('hidden'); }
    function hide() { hud.classList.add('hidden'); }

    function gearLabel(g) {
        // GTA V GetVehicleCurrentGear: 0 = reverse/neutral je nach Speed, 1 = 1st, 2 = 2nd, ...
        if (g === 0) return 'R';
        return g.toString();
    }

    function setPill(node, on) {
        if (!node) return;
        node.classList.remove('on', 'off');
        node.classList.add(on ? 'on' : 'off');
    }

    function warn(node, value, warnThr, critThr) {
        if (!node || !node.parentElement) return;
        node.parentElement.classList.remove('warn', 'crit');
        if (value < critThr) node.parentElement.classList.add('crit');
        else if (value < warnThr) node.parentElement.classList.add('warn');
    }

    function update(d) {
        if (!d) {
            // Nicht im Fahrzeug -> Werte dimmen
            el.speed.textContent = '---';
            el.gear.textContent  = 'N';
            return;
        }
        el.rpm.textContent    = d.rpm;
        el.rpmBar.style.width = Math.max(0, Math.min(100, (d.rpmPct || 0) * 100)) + '%';
        el.speed.textContent  = d.speed;
        el.gear.textContent   = gearLabel(d.gear || 1);
        el.temp.textContent   = Math.round(d.coolantTemp || 85) + '°';
        el.oil.textContent    = Math.round(d.oilPressure || 100) + '%';
        el.boost.textContent  = (d.boost || 0).toFixed(1);
        el.batt.textContent   = Math.round(d.battery || 100) + '%';
        el.fuel.textContent   = d.fuel;
        setPill(el.tc,   d.tcOn);
        setPill(el.abs,  d.absOn);
        setPill(el.flap, d.flap);
        el.map.textContent = 'MAP: ' + (d.ecuMap || 'stock');

        warn(el.temp, d.coolantTemp || 85, 95, 105);
        warn(el.oil,  d.oilPressure || 100, 40, 20);
        warn(el.batt, d.battery || 100, 30, 15);
        warn(el.fuel, d.fuel || 100, 20, 10);

        // Position
        const pos = d.position || 'bottom-right';
        hud.classList.remove('pos-bottom-right', 'pos-bottom-left', 'pos-top-right', 'pos-top-left');
        hud.classList.add('pos-' + pos);
    }

    window.addEventListener('message', function (evt) {
        const d = evt.data || {};
        if (d.action === 'hud:show')   show();
        if (d.action === 'hud:hide')   hide();
        if (d.action === 'hud:update') update(d.data);
    });
})();
