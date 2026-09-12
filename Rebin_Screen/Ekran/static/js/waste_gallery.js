/**
 * REBIN Local Waste Gallery Controller (Section 3.2)
 * Reads locally stored waste captures from Raspberry Pi and displays 3xY grid + Modal view.
 */

class WasteGalleryController {
  constructor() {
    this.gridContainer = document.getElementById('waste-gallery-grid');
    this.modal = document.getElementById('waste-detail-modal');
    this.modalImg = document.getElementById('modal-waste-img');
    this.modalTitle = document.getElementById('modal-waste-type');
    this.modalConf = document.getElementById('modal-confidence-badge');
    this.modalTime = document.getElementById('modal-timestamp');
    this.modalCloseBtn = document.getElementById('btn-modal-close');

    this.records = [];

    this.init();
  }

  init() {
    if (this.modalCloseBtn) {
      this.modalCloseBtn.addEventListener('click', () => {
        this.closeModal();
      });
    }

    if (this.modal) {
      this.modal.addEventListener('click', (e) => {
        if (e.target === this.modal) {
          this.closeModal();
        }
      });
    }

    this.loadGallery();
  }

  async loadGallery() {
    try {
      const resp = await fetch('/api/waste-images');
      if (!resp.ok) throw new Error('Could not fetch local waste images');
      const data = await resp.json();
      this.records = data.records || [];
      this.render();
    } catch (err) {
      console.error('[Gallery] Load failed:', err);
    }
  }

  render() {
    if (!this.gridContainer) return;

    if (this.records.length === 0) {
      this.gridContainer.innerHTML = `
        <div style="grid-column: 1 / -1; display:flex; flex-direction:column; align-items:center; justify-content:center; height:240px; color:#9E9E9E;">
          <p style="font-size:20px; font-weight:700;">Henüz kayıtlı yerel atık görseli bulunmuyor.</p>
        </div>
      `;
      return;
    }

    this.gridContainer.innerHTML = '';

    this.records.forEach((rec) => {
      const card = document.createElement('div');
      card.className = 'gallery-item-card';

      const type = rec.waste_type || 'Plastik';
      const conf = Math.round((rec.confidence || 0.95) * 100);

      card.innerHTML = `
        <img src="${rec.image_url}" alt="${type}" class="gallery-thumbnail-img" loading="lazy" />
        <div class="gallery-item-badge-bottom">
          <span class="badge-waste-tag">${type}</span>
          <span class="badge-confidence-tag">%${conf}</span>
        </div>
      `;

      card.addEventListener('click', (e) => {
        e.stopPropagation();
        this.openModal(rec);
      });

      this.gridContainer.appendChild(card);
    });
  }

  openModal(record) {
    if (!this.modal) return;

    const type = record.waste_type || 'Plastik';
    const conf = Math.round((record.confidence || 0.95) * 100);
    const dateStr = this.formatDate(record.created_at);

    this.modalImg.src = record.image_url;
    this.modalTitle.textContent = type;
    this.modalConf.textContent = `%${conf} Doğruluk`;
    this.modalTime.textContent = dateStr;

    this.modal.classList.remove('hidden');
  }

  closeModal() {
    if (this.modal) {
      this.modal.classList.add('hidden');
    }
  }

  formatDate(isoString) {
    if (!isoString) return 'Az önce';
    try {
      const d = new Date(isoString);
      return d.toLocaleDateString('tr-TR', {
        day: 'numeric',
        month: 'long',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch {
      return isoString;
    }
  }
}

window.addEventListener('DOMContentLoaded', () => {
  window.wasteGalleryController = new WasteGalleryController();
});
