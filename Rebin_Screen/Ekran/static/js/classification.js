/**
 * REBIN Classification Flow Controller (Section 2)
 * Manages Loading, Result, and Not Detected / Error states.
 */

class ClassificationController {
  constructor() {
    this.loadingState = document.getElementById('classifying-loading-state');
    this.resultState = document.getElementById('classifying-result-state');
    this.errorState = document.getElementById('classifying-error-state');

    this.capturedImg = document.getElementById('result-captured-img');
    this.imgFrame = document.getElementById('result-img-frame');
    this.circleProgress = document.getElementById('confidence-circle-progress');
    this.percentVal = document.getElementById('confidence-percent-value');
    this.materialBadge = document.getElementById('result-material-badge');
    this.materialText = document.getElementById('result-material-text');
    this.btnRetry = document.getElementById('btn-error-retry');

    this.cooldownPanel = document.getElementById('result-cooldown-panel');
    this.cooldownTitle = document.getElementById('cooldown-status-title');
    this.cooldownTimerNum = document.getElementById('cooldown-timer-number');
    this.cooldownProgressBar = document.getElementById('cooldown-progress-bar');
    this.cooldownSubtext = document.getElementById('cooldown-subtext');
    this.cooldownSpinnerIcon = document.getElementById('cooldown-spinner-icon');
    
    this.cooldownTimer = null;
    this.returnTimer = null;

    this.CIRCUMFERENCE = 2 * Math.PI * 68; // ~427.26px

    this.init();
  }

  animateCounter(element, targetVal, prefix = '%', suffix = '', duration = 800) {
    if (!element) return;
    const startTime = performance.now();
    const update = (now) => {
      const elapsed = now - startTime;
      const progress = Math.min(elapsed / duration, 1);
      const ease = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(targetVal * ease);
      element.textContent = `${prefix}${current}${suffix}`;
      if (progress < 1) {
        requestAnimationFrame(update);
      }
    };
    requestAnimationFrame(update);
  }

  init() {
    if (this.btnRetry) {
      this.btnRetry.addEventListener('click', () => {
        this.clearTimers();
        if (window.rebinApp) {
          window.rebinApp.navigateTo('menu');
        }
      });
    }
  }

  clearTimers() {
    if (this.cooldownTimer) {
      clearInterval(this.cooldownTimer);
      this.cooldownTimer = null;
    }
    if (this.returnTimer) {
      clearTimeout(this.returnTimer);
      this.returnTimer = null;
    }
  }

  /**
   * Resets classification UI state and returns to idle loop.
   */
  reset() {
    this.clearTimers();
    if (this.loadingState) this.loadingState.classList.add('hidden');
    if (this.resultState) this.resultState.classList.add('hidden');
    if (this.errorState) this.errorState.classList.add('hidden');
    if (window.idleController) {
      window.idleController.start();
    }
  }

  /**
   * Shows the loading state with spinning recycling logo.
   */
  showLoading() {
    this.clearTimers();

    if (window.rebinApp) {
      window.rebinApp.navigateTo('classification');
      window.rebinApp.setHeaderStatus('detecting', 'Atık Algılanıyor...');
    }

    if (this.loadingState) this.loadingState.classList.remove('hidden');
    if (this.resultState) this.resultState.classList.add('hidden');
    if (this.errorState) this.errorState.classList.add('hidden');
  }

  /**
   * Displays classification result with colored frame, confidence gauge, material box,
   * and live cooldown countdown timer showing the waste being routed to its bin.
   */
  showResult(data) {
    this.clearTimers();

    if (window.rebinApp) {
      window.rebinApp.navigateTo('classification');
    }

    if (this.loadingState) this.loadingState.classList.add('hidden');

    if (data.state === 'FAILED' || !data.waste_type || data.waste_type.toLowerCase() === 'bilinmiyor') {
      if (this.errorState) this.errorState.classList.remove('hidden');
      if (this.resultState) this.resultState.classList.add('hidden');
      if (window.rebinApp) {
        window.rebinApp.setHeaderStatus('ready', 'Sistem Hazır');
      }
      
      // Auto return to idle after 4s
      this.returnTimer = setTimeout(() => {
        this.reset();
      }, 4000);
      return;
    }

    if (this.errorState) this.errorState.classList.add('hidden');
    if (this.resultState) this.resultState.classList.remove('hidden');

    const wasteType = (data.waste_type || 'Plastik').trim();
    const conf = Math.max(0.1, Math.min(1.0, Number(data.confidence) || 0.95));
    const percentInt = Math.round(conf * 100);
    const cooldownDuration = Math.max(2.0, Number(data.cooldown_duration || 5.0));

    // Update Image
    if (data.image_url && this.capturedImg) {
      this.capturedImg.src = data.image_url;
    }

    // Material Class Mapping & Color Codes
    // Plastik -> Blue, Metal -> Red, Kağıt -> Orange, Cam -> Dark Green
    const lower = wasteType.toLowerCase();
    let themeClass = 'plastic';
    let displayName = 'PLASTİK';

    if (lower.includes('metal') || lower.includes('teneke')) {
      themeClass = 'metal';
      displayName = 'METAL';
    } else if (lower.includes('kağıt') || lower.includes('kagit') || lower.includes('paper') || lower.includes('karton')) {
      themeClass = 'paper';
      displayName = 'KAĞIT';
    } else if (lower.includes('cam') || lower.includes('glass')) {
      themeClass = 'glass';
      displayName = 'CAM';
    } else {
      themeClass = 'plastic';
      displayName = 'PLASTİK';
    }

    // Update Image Frame Border
    if (this.imgFrame) {
      this.imgFrame.className = `result-frame border-${themeClass}`;
    }

    // Update Confidence Gauge safely using setAttribute (SVG DOM requires setAttribute)
    if (this.circleProgress) {
      this.circleProgress.setAttribute('class', `circle-progress stroke-${themeClass}`);
      this.circleProgress.style.strokeDashoffset = this.CIRCUMFERENCE;
      setTimeout(() => {
        const offset = this.CIRCUMFERENCE * (1 - conf);
        this.circleProgress.style.strokeDashoffset = offset;
      }, 60);
    }
    this.animateCounter(this.percentVal, percentInt, "%", "", 900);

    // Update Material Box
    if (this.materialBadge) {
      this.materialBadge.className = `result-material-box bg-${themeClass}`;
    }
    if (this.materialText) {
      this.materialText.textContent = displayName;
    }

    // Trigger local gallery reload in background
    try {
      if (window.wasteGalleryController) {
        window.wasteGalleryController.loadGallery();
      }
      if (window.occupancyController) {
        window.occupancyController.refresh();
      }
    } catch (_) {}

    // Initialize Cooldown & Hazneye Aktarım Panel
    if (this.cooldownPanel) {
      this.cooldownPanel.classList.remove('hidden');
      if (this.cooldownTitle) this.cooldownTitle.textContent = "Atık Hazneye Aktarılıyor...";
      if (this.cooldownSubtext) this.cooldownSubtext.textContent = "Lütfen atığın hazneye düşmesini bekleyiniz";
      if (this.cooldownSpinnerIcon) {
        this.cooldownSpinnerIcon.className = "cooldown-spinner-icon";
        this.cooldownSpinnerIcon.textContent = "⚙️";
      }
      if (this.cooldownProgressBar) {
        this.cooldownProgressBar.style.backgroundColor = `var(--color-${themeClass})`;
        this.cooldownProgressBar.style.transform = 'scaleX(1)';
        this.cooldownProgressBar.style.width = '100%';
      }
      if (this.cooldownTimerNum) {
        this.cooldownTimerNum.style.color = `var(--color-${themeClass})`;
        this.cooldownTimerNum.textContent = `${cooldownDuration.toFixed(1)}s`;
      }
    }

    if (window.rebinApp) {
      window.rebinApp.setHeaderStatus('cooldown', `Hazne Aktarılıyor (${Math.ceil(cooldownDuration)}s)`);
    }

    // Live Cooldown Countdown using robust Date.now() setInterval
    const startMs = Date.now();
    const totalMs = cooldownDuration * 1000;

    this.cooldownTimer = setInterval(() => {
      const elapsedMs = Date.now() - startMs;
      const remainingMs = Math.max(0, totalMs - elapsedMs);
      const remainingSec = remainingMs / 1000;
      const progressRatio = remainingMs / totalMs;

      if (this.cooldownTimerNum) {
        this.cooldownTimerNum.textContent = `${remainingSec.toFixed(1)}s`;
      }
      if (this.cooldownProgressBar) {
        this.cooldownProgressBar.style.transform = `scaleX(${progressRatio.toFixed(3)})`;
      }
      if (window.rebinApp && remainingSec > 0) {
        window.rebinApp.setHeaderStatus('cooldown', `Hazne Aktarılıyor (${Math.ceil(remainingSec)}s)`);
      }

      if (remainingMs <= 0) {
        clearInterval(this.cooldownTimer);
        this.cooldownTimer = null;

        // Cooldown completed: Show success state
        if (this.cooldownTitle) this.cooldownTitle.textContent = "İşlem Tamamlandı, Tepsi Temizlendi";
        if (this.cooldownSubtext) this.cooldownSubtext.textContent = "Yeni atık yerleştirebilirsiniz.";
        if (this.cooldownTimerNum) this.cooldownTimerNum.textContent = "0.0s";
        if (this.cooldownSpinnerIcon) {
          this.cooldownSpinnerIcon.className = "cooldown-spinner-icon done";
          this.cooldownSpinnerIcon.textContent = "✅";
        }
        if (this.cooldownProgressBar) {
          this.cooldownProgressBar.style.transform = 'scaleX(0)';
        }
        if (window.rebinApp) {
          window.rebinApp.setHeaderStatus('ready', 'Sistem Hazır');
        }

        // Auto return to idle screens after 1.0s confirmation
        this.returnTimer = setTimeout(() => {
          console.log('[Classification] Cooldown completed successfully. Returning to idle screens.');
          this.reset();
        }, 1000);
      }
    }, 50);
  }
}

window.addEventListener('DOMContentLoaded', () => {
  window.classificationController = new ClassificationController();
});
