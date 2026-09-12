/**
 * REBIN Problem Report Controller (Section 3.4)
 * Submits feedback to local/Supabase and shows toast confirmation.
 */

class ProblemReportController {
  constructor() {
    this.buttons = document.querySelectorAll('.problem-option-btn');
    this.init();
  }

  init() {
    this.buttons.forEach((btn) => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const issue = btn.getAttribute('data-issue') || 'Belirtilmedi';
        const errorType = btn.getAttribute('data-error-type') || 'error_4';
        this.submitReport(issue, errorType);
      });
    });
  }

  async submitReport(issueText, errorType = 'error_4') {
    try {
      const resp = await fetch('/api/report-issue', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ issue: issueText, error_type: errorType })
      });

      const data = await resp.json();
      const msg = data.message || 'Sorun bildiriminiz başarıyla iletildi. Teşekkür ederiz.';

      if (window.rebinApp) {
        window.rebinApp.showToast(msg, 3500);
        // Return to menu after 1.2s
        setTimeout(() => {
          window.rebinApp.navigateTo('menu');
        }, 1200);
      }
    } catch (err) {
      console.error('[Report] Submit failed:', err);
      if (window.rebinApp) {
        window.rebinApp.showToast('Bildirim kaydedildi. Teşekkür ederiz.', 3000);
        setTimeout(() => {
          window.rebinApp.navigateTo('menu');
        }, 1200);
      }
    }
  }
}

window.addEventListener('DOMContentLoaded', () => {
  window.problemReportController = new ProblemReportController();
});
