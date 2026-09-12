/**
 * REBIN Touch Display Kiosk - Core Application Controller
 * Handles screen navigation, top header state, idle timeout, and SSE real-time triggers.
 */

class RebinApp {
  constructor() {
    this.currentScreen = 'idle-name';
    this.previousScreen = null;
    this.isIdleMode = true;
    this.idleReturnTimeout = null;
    this.IDLE_TIMEOUT_MS = 10000; // 10 seconds of inactivity on submenus returns to idle

    this.screens = {
      'idle-name': document.getElementById('screen-idle-name'),
      'idle-promo': document.getElementById('screen-idle-promo'),
      'idle-guide': document.getElementById('screen-idle-guide'),
      'menu': document.getElementById('screen-menu'),
      'occupancy': document.getElementById('screen-occupancy'),
      'waste-gallery': document.getElementById('screen-waste-gallery'),
      'qr-view': document.getElementById('screen-qr-view'),
      'problem-report': document.getElementById('screen-problem-report'),
      'classification': document.getElementById('screen-classification'),
    };

    this.btnBack = document.getElementById('btn-back');
    this.headerLogoBtn = document.getElementById('header-logo-btn');
    this.btnExit = document.getElementById('btn-header-exit');
    this.exitModal = document.getElementById('exit-confirm-modal');
    this.btnExitCancel = document.getElementById('btn-exit-cancel');
    this.btnExitConfirm = document.getElementById('btn-exit-confirm');
    this.qrZoomModal = document.getElementById('qr-zoom-modal');
    this.btnZoomQr = document.getElementById('btn-zoom-qr');
    this.btnZoomQrTag = document.getElementById('btn-zoom-qr-tag');
    this.btnQrZoomClose = document.getElementById('btn-qr-zoom-close');
    this.toastElement = document.getElementById('toast-notification');
    this.toastMessage = document.getElementById('toast-message');
    this.toastTimer = null;

    this.init();
  }

  init() {
    this.bindEvents();
    this.initSSE();
    this.resetActivityTimer();
    console.log('[REBIN App] Kiosk System Initialized (1280x720 Landscape)');
  }

  bindEvents() {
    // Back Button Click
    this.btnBack.addEventListener('click', (e) => {
      e.stopPropagation();
      this.handleBackNavigation();
    });

    // Header Logo Click -> Returns to Main Menu if not in idle
    this.headerLogoBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (!this.isIdleMode) {
        this.navigateTo('menu');
      }
    });

    // Menu Navigation Buttons
    document.getElementById('menu-btn-occupancy')?.addEventListener('click', () => {
      this.navigateTo('occupancy');
      if (window.occupancyController) window.occupancyController.refresh();
    });

    document.getElementById('menu-btn-waste-gallery')?.addEventListener('click', () => {
      this.navigateTo('waste-gallery');
      if (window.wasteGalleryController) window.wasteGalleryController.loadGallery();
    });

    document.getElementById('menu-btn-qr-view')?.addEventListener('click', () => {
      this.navigateTo('qr-view');
    });

    document.getElementById('menu-btn-problem-report')?.addEventListener('click', () => {
      this.navigateTo('problem-report');
    });

    // Exit Button & Modal Listeners
    this.btnExit?.addEventListener('click', (e) => {
      e.stopPropagation();
      this.openExitModal();
    });

    this.btnExitCancel?.addEventListener('click', (e) => {
      e.stopPropagation();
      this.closeExitModal();
    });

    this.btnExitConfirm?.addEventListener('click', async (e) => {
      e.stopPropagation();
      await this.handleExit();
    });

    this.exitModal?.addEventListener('click', (e) => {
      if (e.target === this.exitModal) {
        this.closeExitModal();
      }
    });

    // QR Zoom Modal Listeners
    const openQrZoom = (e) => {
      e.stopPropagation();
      this.openQrZoomModal();
    };

    this.btnZoomQr?.addEventListener('click', openQrZoom);
    this.btnZoomQrTag?.addEventListener('click', openQrZoom);

    this.btnQrZoomClose?.addEventListener('click', (e) => {
      e.stopPropagation();
      this.closeQrZoomModal();
    });

    this.qrZoomModal?.addEventListener('click', (e) => {
      if (e.target === this.qrZoomModal) {
        this.closeQrZoomModal();
      }
    });

    // Global Activity & Touch Ripple Listener
    document.addEventListener('pointerdown', (e) => {
      this.resetActivityTimer();
      this.spawnTouchRipple(e.clientX, e.clientY);
    });
  }

  /**
   * Navigates to a target screen and updates top bar visibility.
   */
  navigateTo(screenKey, options = {}) {
    if (!this.screens[screenKey]) {
      console.error(`[Navigation] Screen '${screenKey}' not found.`);
      return;
    }

    const isTargetIdle = screenKey.startsWith('idle-');
    this.isIdleMode = isTargetIdle;

    // Record history
    if (!isTargetIdle && screenKey !== 'menu') {
      this.previousScreen = this.currentScreen === 'menu' ? 'menu' : this.previousScreen || 'menu';
    }

    // Hide all screens
    Object.values(this.screens).forEach((el) => {
      if (el) el.classList.remove('active');
    });

    // Activate target screen
    this.screens[screenKey].classList.add('active');
    this.currentScreen = screenKey;

    // Header Back Button visibility rule:
    // Visible on subpages (as '< Geri') AND on the main menu (as '< Ana Ekran')
    const isIdleOrClassifying = isTargetIdle || screenKey === 'classification';
    if (!isIdleOrClassifying) {
      this.btnBack.classList.remove('hidden');
      const labelSpan = this.btnBack.querySelector('span');
      if (labelSpan) {
        labelSpan.textContent = screenKey === 'menu' ? 'Ana Ekran' : 'Geri';
      }
    } else {
      this.btnBack.classList.add('hidden');
    }

    // Reset inactivity timer
    this.resetActivityTimer();
  }



  spawnTouchRipple(x, y) {
    if (x === undefined || y === undefined) return;
    const ripple = document.createElement('div');
    ripple.className = 'touch-ripple-effect';
    ripple.style.left = x + "px";
    ripple.style.top = y + "px";
    document.body.appendChild(ripple);
    setTimeout(() => {
      ripple.remove();
    }, 450);
  }

  openQrZoomModal() {
    if (window.idleController) {
      window.idleController.pause(); // Freeze 5-second rotation timer while QR is enlarged
    }
    if (this.qrZoomModal) {
      this.qrZoomModal.classList.remove('hidden');
    }
  }

  closeQrZoomModal() {
    if (this.qrZoomModal) {
      this.qrZoomModal.classList.add('hidden');
    }
    if (this.isIdleMode && window.idleController) {
      window.idleController.resume(); // Resume 5-second rotation timer after returning
    }
  }

  openExitModal() {
    if (this.exitModal) {
      this.exitModal.classList.remove('hidden');
    }
  }

  closeExitModal() {
    if (this.exitModal) {
      this.exitModal.classList.add('hidden');
    }
  }

  async handleExit() {
    this.showToast('Arayüz kapatılıyor...', 4000);
    this.closeExitModal();
    try {
      await fetch('/api/exit', { method: 'POST' });
    } catch (_) {}
    setTimeout(() => {
      window.close();
    }, 600);
  }

  handleBackNavigation() {
    if (['occupancy', 'waste-gallery', 'qr-view', 'problem-report'].includes(this.currentScreen)) {
      this.navigateTo('menu');
    } else if (this.currentScreen === 'menu') {
      if (window.idleController) window.idleController.start();
    }
  }

  resetActivityTimer() {
    if (this.idleReturnTimeout) {
      clearTimeout(this.idleReturnTimeout);
      this.idleReturnTimeout = null;
    }

    // If on a menu/subpage and no touch for 30s, return to idle loop
    if (!this.isIdleMode && this.currentScreen !== 'classification') {
      this.idleReturnTimeout = setTimeout(() => {
        console.log('[Inactivity] 10s timeout reached. Returning to idle rotation.');
        if (window.idleController) window.idleController.start();
      }, this.IDLE_TIMEOUT_MS);
    }
  }

  showToast(message, duration = 3000) {
    if (this.toastTimer) clearTimeout(this.toastTimer);
    this.toastMessage.textContent = message;
    this.toastElement.classList.remove('hidden');

    this.toastTimer = setTimeout(() => {
      this.toastElement.classList.add('hidden');
    }, duration);
  }

  /**
   * Sets top header status pill style and text.
   * states: 'ready' (green), 'detecting' (amber), 'cooldown' (blue), 'clearing' (purple)
   */
  setHeaderStatus(state = 'ready', text = '') {
    const pill = document.getElementById('header-status-pill');
    const label = document.getElementById('header-status-text');
    if (!pill || !label) return;

    pill.className = 'header-status-pill';
    if (state === 'ready') {
      pill.classList.add('status-ready');
      label.textContent = text || 'Sistem Hazır';
    } else if (state === 'detecting') {
      pill.classList.add('status-detecting');
      label.textContent = text || 'Atık Algılanıyor...';
    } else if (state === 'cooldown') {
      pill.classList.add('status-cooldown');
      label.textContent = text || 'Hazne Aktarılıyor';
    } else if (state === 'clearing') {
      pill.classList.add('status-clearing');
      label.textContent = text || 'Tepsi Temizleniyor...';
    }
  }

  /**
   * Connects to Server-Sent Events (SSE) for real-time classification events.
   */
  initSSE() {
    const sse = new EventSource('/api/events');

    sse.addEventListener('classification_started', (e) => {
      console.log('[SSE] Classification Started:', e.data);
      if (window.idleController) window.idleController.pause();
      this.setHeaderStatus('detecting', 'Atık Algılanıyor...');
      if (window.classificationController) {
        window.classificationController.showLoading();
      }
    });

    sse.addEventListener('classification_result', (e) => {
      try {
        const data = JSON.parse(e.data);
        console.log('[SSE] Classification Result:', data);
        if (window.classificationController) {
          window.classificationController.showResult(data);
        }
      } catch (err) {
        console.error('[SSE] Parse error:', err);
      }
    });

    sse.addEventListener('system_ready', (e) => {
      console.log('[SSE] System Ready');
      this.setHeaderStatus('ready', 'Sistem Hazır');
      if (this.currentScreen === 'classification') {
        if (window.classificationController) {
          window.classificationController.reset();
        } else if (window.idleController) {
          window.idleController.start();
        }
      }
    });

    sse.onerror = () => {
      // Reconnection handled automatically by EventSource
    };
  }
}

// Global App Instance
window.addEventListener('DOMContentLoaded', () => {
  window.rebinApp = new RebinApp();
});

// Auto-check for user added PNGs (logo.png, pet_bottle.png)
window.addEventListener('DOMContentLoaded', async () => {
  try {
    const res = await fetch('/api/bin-info');
    if (res.ok) {
      const info = await res.json();
      if (info.has_custom_logo) {
        const headerLogo = document.getElementById('header-logo-img');
        const idleLogo = document.getElementById('idle-large-logo-img');
        if (headerLogo) headerLogo.src = '/assets/logo.png';
        if (idleLogo) idleLogo.src = '/assets/logo.png';
      }
      if (info.has_custom_bottle) {
        const bottleImg = document.getElementById('guide-bottle-img');
        if (bottleImg) bottleImg.src = '/assets/pet_bottle.png';
      }
    }
  } catch (_) {}
});
