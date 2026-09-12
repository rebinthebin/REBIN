/**
 * REBIN Idle Screen Controller (Section 1)
 * Cycles through 3 idle screens every 5 seconds with a smooth, elegant depth crossfade & elevation transition:
 *   1.1 İsim Ekranı (idle-name)
 *   1.2 Mobil Uygulama Tanıtım Ekranı (idle-promo)
 *   1.3 Yönlendirme Ekranı (idle-guide)
 *
 * Touching any idle screen immediately opens the 2x2 Main Menu.
 * Clicking on the QR code pauses the timer and opens the enlarged QR modal.
 */

class IdleController {
  constructor() {
    this.idleScreens = ['idle-name', 'idle-promo', 'idle-guide'];
    this.currentIndex = 0;
    this.timer = null;
    this.INTERVAL_MS = 5000; // 5 seconds per screen
    this.isRunning = false;

    this.init();
  }

  init() {
    this.bindTouchEvents();
    this.start();
  }

  bindTouchEvents() {
    this.idleScreens.forEach((screenKey) => {
      const el = document.getElementById(`screen-${screenKey}`);
      if (el) {
        el.addEventListener('click', (e) => {
          // If clicking on the QR zoom trigger, let the zoom modal handle it
          if (e.target.closest('#btn-zoom-qr') || e.target.closest('#btn-zoom-qr-tag')) {
            return;
          }
          e.stopPropagation();
          this.handleTouchWakeup();
        });
      }
    });
  }

  handleTouchWakeup() {
    console.log('[Idle] Screen touched. Opening 2x2 Main Menu.');
    this.pause();
    if (window.rebinApp) {
      window.rebinApp.navigateTo('menu');
    }
  }

  start() {
    this.isRunning = true;
    this.currentIndex = 0;

    // Reset all idle screens
    this.idleScreens.forEach((key, idx) => {
      const el = document.getElementById(`screen-${key}`);
      if (el) {
        el.classList.remove('slide-out-fade', 'slide-in-prep', 'slide-out-left', 'slide-in-right');
        if (idx === 0) {
          el.classList.add('active');
        } else {
          el.classList.remove('active');
        }
      }
    });

    if (window.rebinApp) {
      window.rebinApp.navigateTo('idle-name');
    }

    this.scheduleNext();
  }

  pause() {
    this.isRunning = false;
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }
  }

  resume() {
    this.isRunning = true;
    if (this.timer) clearTimeout(this.timer);
    this.scheduleNext();
  }

  scheduleNext() {
    if (!this.isRunning) return;

    if (this.timer) clearTimeout(this.timer);

    this.timer = setTimeout(() => {
      if (!this.isRunning) return;

      if (window.rebinApp && window.rebinApp.isIdleMode) {
        this.goToNextSlide();
      }
    }, this.INTERVAL_MS);
  }

  goToNextSlide() {
    if (!this.isRunning) return;

    const prevIndex = this.currentIndex;
    this.currentIndex = (this.currentIndex + 1) % this.idleScreens.length;
    const prevKey = this.idleScreens[prevIndex];
    const nextKey = this.idleScreens[this.currentIndex];

    const prevEl = document.getElementById(`screen-${prevKey}`);
    const nextEl = document.getElementById(`screen-${nextKey}`);

    if (prevEl && nextEl) {
      // 1. Prepare next screen in soft elevation
      nextEl.classList.remove('slide-out-fade', 'active');
      nextEl.classList.add('slide-in-prep');

      // Force browser reflow
      void nextEl.offsetWidth;

      // 2. Smoothly dissolve previous screen into depth
      prevEl.classList.remove('active');
      prevEl.classList.add('slide-out-fade');

      // 3. Float next screen into crisp focus
      nextEl.classList.remove('slide-in-prep');
      nextEl.classList.add('active');

      // 4. Clean up after transition
      setTimeout(() => {
        prevEl.classList.remove('slide-out-fade');
      }, 850);

      if (window.rebinApp) {
        window.rebinApp.currentScreen = nextKey;
      }
    }

    this.scheduleNext();
  }
}

window.addEventListener('DOMContentLoaded', () => {
  window.idleController = new IdleController();
});
