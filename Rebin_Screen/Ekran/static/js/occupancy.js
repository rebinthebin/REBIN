/**
 * REBIN Occupancy Controller (Section 3.1)
 * Integrates with Supabase /api/bin-info and updates General and Material occupancy gauges
 * with smooth count-up animations and circular SVG transitions.
 */

class OccupancyController {
  constructor() {
    this.generalPercentEl = document.getElementById('general-occupancy-percent');
    this.generalGaugeFill = document.getElementById('general-gauge-fill');
    this.binStatusText = document.getElementById('bin-status-text');

    this.miniFills = {
      plastic: document.getElementById('mini-progress-plastic'),
      paper: document.getElementById('mini-progress-paper'),
      glass: document.getElementById('mini-progress-glass'),
      metal: document.getElementById('mini-progress-metal'),
    };

    this.percentLabels = {
      plastic: document.getElementById('waste-percent-plastic'),
      paper: document.getElementById('waste-percent-paper'),
      glass: document.getElementById('waste-percent-glass'),
      metal: document.getElementById('waste-percent-metal'),
    };

    this.GAUGE_CIRCUMFERENCE = 2 * Math.PI * 82; // ~515.22px
    this.MINI_CIRCUMFERENCE = 2 * Math.PI * 32;  // ~201.06px

    this.init();
  }

  init() {
    this.refresh();
    // Periodically refresh every 45s
    setInterval(() => this.refresh(), 45000);
  }

  async refresh() {
    try {
      const resp = await fetch('/api/bin-info');
      if (!resp.ok) throw new Error('Network error');
      const data = await resp.json();
      this.render(data);
    } catch (err) {
      console.warn('[Occupancy] Fetch failed, using cached values:', err);
    }
  }

  animateCounter(element, targetVal, prefix = '%', suffix = '', duration = 800) {
    if (!element) return;
    const startTime = performance.now();
    const update = (now) => {
      const elapsed = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // Ease out cubic
      const ease = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(targetVal * ease);
      element.textContent = `${prefix}${current}${suffix}`;
      if (progress < 1) {
        requestAnimationFrame(update);
      }
    };
    requestAnimationFrame(update);
  }

  render(bin) {
    if (!bin) return;

    const glass = Number(bin.occupancy_glass || 0);
    const metal = Number(bin.occupancy_metal || 0);
    const paper = Number(bin.occupancy_paper || 0);
    const plastic = Number(bin.occupancy_plastic || 0);
    const general = Number(bin.general !== undefined ? bin.general : (glass + metal + paper + plastic) / 4);

    // 1. Render General Gauge with smooth count-up
    const generalPercent = Math.round(general * 100);
    this.animateCounter(this.generalPercentEl, generalPercent, '%', '', 900);

    if (this.generalGaugeFill) {
      const offset = this.GAUGE_CIRCUMFERENCE * (1 - Math.min(1, general));
      this.generalGaugeFill.style.strokeDashoffset = offset;
    }

    if (this.binStatusText) {
      const statusLabel = bin.is_active ? 'Kutu Aktif' : 'Bakımda';
      this.binStatusText.textContent = `${statusLabel} (${bin.bin_id || 'pbin_0001'})`;
    }

    // 2. Render Material 2x2 Cards with mini animated gauges
    const materials = [
      { key: 'plastic', level: plastic },
      { key: 'paper', level: paper },
      { key: 'glass', level: glass },
      { key: 'metal', level: metal },
    ];

    materials.forEach(({ key, level }) => {
      const pct = Math.round(level * 100);
      this.animateCounter(this.percentLabels[key], pct, '%', ' Dolu', 800);

      if (this.miniFills[key]) {
        const offset = this.MINI_CIRCUMFERENCE * (1 - Math.min(1, level));
        this.miniFills[key].style.strokeDashoffset = offset;
      }
    });
  }
}

window.addEventListener('DOMContentLoaded', () => {
  window.occupancyController = new OccupancyController();
});
