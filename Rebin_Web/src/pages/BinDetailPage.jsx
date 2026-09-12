import { useState, useEffect, useRef } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import {
  ArrowLeft, Download, Printer, ToggleLeft, ToggleRight, X,
  Calendar, Image as ImageIcon, QrCode, AlertTriangle, Wrench, CheckCircle,
} from 'lucide-react'
import { fetchBinById, fetchBinImages, toggleBinActive, fetchBinErrors, clearBinErrors } from '../services/supabase'
import { calcOccupancy, formatDate, WASTE_COLORS, WASTE_BG_COLORS, WASTE_LABELS } from '../utils/binUtils'
import CircularProgress from '../components/CircularProgress'
import LoadingSpinner from '../components/LoadingSpinner'

const wasteFields = [
  { key: 'plastic', field: 'occupancy_plastic' },
  { key: 'paper', field: 'occupancy_paper' },
  { key: 'glass', field: 'occupancy_glass' },
  { key: 'metal', field: 'occupancy_metal' },
]

// Hata türleri listesi
const ERROR_TYPES = [
  { key: 'error_1', label: 'Rebin malzemeyi algılamıyor!' },
  { key: 'error_2', label: 'Rebin malzemeyi sınıflandırmıyor!' },
  { key: 'error_3', label: 'Rebin malzemeyi ayrıştırmıyor' },
  { key: 'error_4', label: 'Diğer nedenler' },
]

// ─── Görevlendirme Toast ──────────────────────────────────────────────────────
function AssignToast({ onClose }) {
  useEffect(() => {
    const t = setTimeout(onClose, 4000)
    return () => clearTimeout(t)
  }, [onClose])

  return (
    <div
      className="fixed bottom-6 left-1/2 -translate-x-1/2 z-[9999] flex items-center gap-3
                 bg-green-600 text-white px-6 py-4 rounded-2xl shadow-2xl
                 animate-[slideUp_0.3s_ease-out]"
      style={{ animation: 'slideUp 0.3s ease-out' }}
    >
      <CheckCircle className="w-5 h-5 shrink-0" />
      <div>
        <p className="font-semibold text-sm">Görev Bildirimi Oluşturuldu</p>
        <p className="text-xs text-green-100 mt-0.5">Saha ekibine görev bildirimi oluşturuldu.</p>
      </div>
      <button onClick={onClose} className="ml-2 hover:text-green-200">
        <X className="w-4 h-4" />
      </button>
      <style>{`
        @keyframes slideUp {
          from { opacity: 0; transform: translate(-50%, 16px); }
          to   { opacity: 1; transform: translate(-50%, 0); }
        }
      `}</style>
    </div>
  )
}

// ─── Görevlendirme Onay Modalı ────────────────────────────────────────────────
function AssignModal({ onClose, onConfirm, loading }) {
  return (
    <div
      className="fixed inset-0 z-[9998] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden"
        onClick={(e) => e.stopPropagation()}
        style={{ animation: 'modalPop 0.22s cubic-bezier(.34,1.56,.64,1) both' }}
      >
        <div className="h-1 w-full bg-gradient-to-r from-amber-400 to-yellow-500" />
        <div className="p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center">
              <Wrench className="w-5 h-5 text-amber-600" />
            </div>
            <h2 className="text-lg font-bold text-dark">Birimi Görevlendir</h2>
          </div>
          <p className="text-sm text-gray-600 mb-6">
            Bu kutu için saha ekibine görev bildirimi oluşturulacak. Devam etmek istiyor musunuz?
          </p>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              disabled={loading}
              className="flex-1 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors disabled:opacity-50"
            >
              İptal
            </button>
            <button
              onClick={onConfirm}
              disabled={loading}
              className="flex-1 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-600 text-white text-sm font-semibold transition-colors flex items-center justify-center gap-2 disabled:opacity-50"
            >
              <Wrench className="w-4 h-4" />
              {loading ? 'Görevlendiriliyor...' : 'Görevlendir'}
            </button>
          </div>
        </div>
      </div>
      <style>{`
        @keyframes modalPop {
          from { opacity: 0; transform: scale(0.92) translateY(8px); }
          to   { opacity: 1; transform: scale(1)    translateY(0); }
        }
      `}</style>
    </div>
  )
}

// ─── Ana Sayfa ────────────────────────────────────────────────────────────────
export default function BinDetailPage() {
  const { id } = useParams()
  const navigate = useNavigate()
  const [bin, setBin] = useState(null)
  const [images, setImages] = useState([])
  const [binErrors, setBinErrors] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [toggling, setToggling] = useState(false)
  const [assigning, setAssigning] = useState(false)
  const [selectedImage, setSelectedImage] = useState(null)
  const [qrImageLoaded, setQrImageLoaded] = useState(false)
  const [qrImageError, setQrImageError] = useState(false)
  const [showAssignModal, setShowAssignModal] = useState(false)
  const [showToast, setShowToast] = useState(false)
  const qrRef = useRef(null)

  useEffect(() => {
    Promise.all([fetchBinById(id), fetchBinImages(id), fetchBinErrors(id)])
      .then(([binData, imagesData, errorsData]) => {
        setBin(binData)
        setImages(imagesData || [])
        setBinErrors(errorsData)
      })
      .catch(err => setError(err.message))
      .finally(() => setLoading(false))
  }, [id])

  const handleToggleActive = async () => {
    if (!bin) return
    setToggling(true)
    try {
      const updated = await toggleBinActive(bin.bin_id, !bin.is_active)
      setBin(updated)
    } catch (err) {
      console.error(err)
    } finally {
      setToggling(false)
    }
  }

  const handleAssignConfirm = async () => {
    if (!bin) return
    setAssigning(true)
    try {
      await clearBinErrors(bin.bin_id)
      setBinErrors(prev => prev ? { ...prev, error_1: 0, error_2: 0, error_3: 0, error_4: 0 } : null)
      setShowAssignModal(false)
      setShowToast(true)
    } catch (err) {
      console.error('Hata sıfırlanırken hata oluştu:', err)
      alert('Görevlendirme yapılırken bir hata oluştu: ' + (err.message || err))
    } finally {
      setAssigning(false)
    }
  }

  const downloadQR = async () => {
    if (!bin?.qr_image_url) return
    try {
      const response = await fetch(bin.qr_image_url)
      const blob = await response.blob()
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      const ext = bin.qr_image_url.split('.').pop().split('?')[0] || 'png'
      a.download = `QR_${id}.${ext}`
      a.click()
      URL.revokeObjectURL(url)
    } catch (e) {
      console.error('QR indirme hatası:', e)
    }
  }

  const printQR = () => {
    if (!bin?.qr_image_url) return
    const printWindow = window.open('', '_blank')
    if (!printWindow) return
    printWindow.document.write(`
      <html><head><title>QR - ${id}</title></head>
      <body style="display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;font-family:sans-serif;gap:16px;">
        <img src="${bin.qr_image_url}" style="max-width:240px;height:auto;" alt="QR Kod" />
        <p style="font-size:14px;color:#555;">Kutu ID: ${id}</p>
      </body></html>
    `)
    printWindow.document.close()
    printWindow.print()
  }

  if (loading) return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <LoadingSpinner text="Kutu detayları yükleniyor..." />
    </div>
  )

  if (error || !bin) return (
    <div className="max-w-5xl mx-auto px-4 py-8 text-center">
      <p className="text-red-500">Kutu bulunamadı: {error}</p>
      <button onClick={() => navigate('/kutular')} className="mt-4 text-primary underline text-sm">
        Kutulara Dön
      </button>
    </div>
  )

  const occupancy = calcOccupancy(bin)

  // Arızalı mı?
  const hasError =
    bin.status === 'out_of_order' ||
    (binErrors &&
      ((binErrors.error_1 ?? 0) > 0 ||
        (binErrors.error_2 ?? 0) > 0 ||
        (binErrors.error_3 ?? 0) > 0 ||
        (binErrors.error_4 ?? 0) > 0))

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8 page-enter space-y-6">
      {/* Geri Butonu */}
      <button
        onClick={() => navigate(-1)}
        className="flex items-center gap-2 text-sm text-gray-500 hover:text-dark transition-colors"
      >
        <ArrowLeft className="w-4 h-4" />
        Geri
      </button>

      {/* Başlık ve Aktif Toggle */}
      <div className={`rounded-2xl shadow-card p-6 border-2 ${hasError ? 'bg-amber-50 border-amber-400' : 'bg-white border-gray-100'}`}>
        <div className="flex items-start justify-between flex-wrap gap-4">
          <div>
            <div className="flex items-center gap-2">
              {hasError && <AlertTriangle className="w-5 h-5 text-amber-500" />}
              <h1 className="text-2xl font-bold text-dark">{bin.name || bin.bin_id}</h1>
            </div>
            <p className="text-sm text-gray-400 font-mono mt-1">{bin.bin_id}</p>
            <div className="flex items-center gap-2 mt-2 flex-wrap">
              <span className={`text-xs font-semibold px-2 py-0.5 rounded-full ${bin.type === 'private' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'}`}>
                {bin.type === 'private' ? 'Özel' : 'Topluma Açık'}
              </span>
              {hasError && (
                <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-yellow-100 text-yellow-800 flex items-center gap-1">
                  <AlertTriangle className="w-3 h-3" />
                  ARIZALI !
                </span>
              )}
              <span className="text-xs text-gray-400 flex items-center gap-1">
                <Calendar className="w-3 h-3" />
                Son Boşaltım: {formatDate(bin.last_emptying)}
              </span>
            </div>
          </div>

          {/* Aktif Toggle */}
          <button
            onClick={handleToggleActive}
            disabled={toggling}
            className={`flex items-center gap-2 font-semibold px-5 py-2.5 rounded-xl transition-all text-sm ${bin.is_active
                ? 'bg-green-100 text-green-700 hover:bg-green-200'
                : 'bg-red-100 text-red-600 hover:bg-red-200'
              } disabled:opacity-50`}
          >
            {bin.is_active ? <ToggleRight className="w-5 h-5" /> : <ToggleLeft className="w-5 h-5" />}
            {toggling ? 'Güncelleniyor...' : bin.is_active ? 'Aktif' : 'Deaktif'}
          </button>
        </div>
      </div>

      {/* ─── Bildirilen Sorunlar Paneli ─────────────────────────────────────── */}
      {hasError && (
        <div className="bg-white rounded-2xl shadow-card border-2 border-amber-400 overflow-hidden">
          {/* Renkli üst şerit */}
          <div className="h-1.5 w-full bg-gradient-to-r from-amber-400 to-yellow-500" />
          <div className="p-6">
            {/* Başlık */}
            <div className="flex items-start justify-between flex-wrap gap-3 mb-5">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 bg-amber-100 rounded-xl flex items-center justify-center shrink-0">
                  <AlertTriangle className="w-5 h-5 text-amber-600" />
                </div>
                <div>
                  <h2 className="font-bold text-amber-800 text-lg">Bildirilen Sorunlar</h2>
                  <p className="text-xs text-amber-600">Bu kutu için aktif sorun bildirimi mevcuttur</p>
                </div>
              </div>
              {binErrors?.last_reported_at && (
                <div className="flex items-center gap-1.5 text-xs text-amber-800 bg-amber-100/80 border border-amber-300/60 px-3 py-1.5 rounded-xl font-semibold self-center sm:self-auto">
                  <Calendar className="w-3.5 h-3.5 text-amber-600 shrink-0" />
                  <span>Son Bildirim: {formatDate(binErrors.last_reported_at)}</span>
                </div>
              )}
            </div>

            {/* Hata listesi */}
            <div className="space-y-3">
              {ERROR_TYPES.map(({ key, label }) => {
                const count = binErrors?.[key] ?? 0
                const isActive = count > 0
                return (
                  <div
                    key={key}
                    className={`flex items-center justify-between rounded-xl px-4 py-3 transition-all ${isActive
                        ? 'bg-amber-50 border border-amber-200'
                        : 'bg-gray-50 border border-gray-100 opacity-50'
                      }`}
                  >
                    <div className="flex items-center gap-3">
                      <div className={`w-2 h-2 rounded-full shrink-0 ${isActive ? 'bg-amber-500' : 'bg-gray-300'}`} />
                      <span className={`text-sm font-medium ${isActive ? 'text-amber-900' : 'text-gray-500'}`}>
                        {label}
                      </span>
                    </div>
                    <span
                      className={`text-xs font-bold px-3 py-1 rounded-full ${isActive
                          ? 'bg-amber-200 text-amber-900'
                          : 'bg-gray-200 text-gray-400'
                        }`}
                    >
                      {count} Bildirim
                    </span>
                  </div>
                )
              })}
            </div>

            {/* Görevlendir Butonu */}
            <button
              onClick={() => setShowAssignModal(true)}
              className="mt-5 w-full flex items-center justify-center gap-2 bg-amber-500 hover:bg-amber-600 active:bg-amber-700
                         text-white font-bold py-3.5 rounded-xl transition-all shadow-md hover:shadow-lg
                         text-sm tracking-wide"
            >
              <Wrench className="w-4 h-4" />
              İlgili Birimi Görevlendir
            </button>
          </div>
        </div>
      )}

      {/* Doluluk Göstergeleri */}
      <div className="bg-white rounded-2xl shadow-card border border-gray-100 p-6">
        <h2 className="font-bold text-dark mb-5">Bölme Doluluk Oranları</h2>
        <div className="flex flex-wrap items-center justify-around gap-6">
          {/* Genel */}
          <div className="flex flex-col items-center">
            <CircularProgress
              value={occupancy}
              color={occupancy >= 0.85 ? '#EF5350' : occupancy >= 0.65 ? '#FFCA28' : '#38A169'}
              size={110}
              strokeWidth={10}
              label="Genel Doluluk"
              fontSize={18}
            />
          </div>

          <div className="w-px h-24 bg-gray-100 hidden sm:block" />

          {/* 4 Bölme */}
          {wasteFields.map(({ key, field }) => (
            <div
              key={key}
              className="flex flex-col items-center gap-2 p-3.5 rounded-2xl border border-black/5 transition-colors duration-200"
              style={{ backgroundColor: WASTE_BG_COLORS[key] }}
            >
              <CircularProgress
                value={bin[field] ?? 0}
                color={WASTE_COLORS[key]}
                size={78}
                strokeWidth={7}
                label={WASTE_LABELS[key]}
                fontSize={13}
              />
              {/* Bar */}
              <div className="w-16">
                <div className="w-full bg-black/10 rounded-full h-1.5">
                  <div
                    className="h-1.5 rounded-full transition-all"
                    style={{
                      width: `${(bin[field] ?? 0) * 100}%`,
                      background: WASTE_COLORS[key],
                    }}
                  />
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Atık Fotoğraf Galerisi */}
        <div className="bg-white rounded-2xl shadow-card border border-gray-100 p-6">
          <div className="flex items-center gap-2 mb-4">
            <ImageIcon className="w-5 h-5 text-primary" />
            <h2 className="font-bold text-dark">Atık Fotoğraf Geçmişi</h2>
            <span className="text-xs text-gray-400 ml-auto">{images.length} fotoğraf</span>
          </div>

          {images.length === 0 ? (
            <div className="text-center py-10 text-gray-400">
              <ImageIcon className="w-10 h-10 mx-auto mb-2 opacity-30" />
              <p className="text-sm">Henüz fotoğraf yok</p>
            </div>
          ) : (
            <div className="grid grid-cols-3 gap-2">
              {images.map(img => (
                <button
                  key={img.id}
                  onClick={() => setSelectedImage(img)}
                  className="aspect-square rounded-xl overflow-hidden border-2 border-transparent hover:border-primary transition-all group relative"
                >
                  <img
                    src={img.image_url}
                    alt={img.waste_type}
                    className="w-full h-full object-cover group-hover:scale-105 transition-transform"
                    onError={e => { e.target.src = 'https://via.placeholder.com/150?text=?' }}
                  />
                  <div className="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-end p-1">
                    <span className="text-white text-xs font-semibold capitalize">{img.waste_type}</span>
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Kutu QR Kodu */}
        <div className="bg-white rounded-2xl shadow-card border border-gray-100 p-6">
          <div className="flex items-center gap-2 mb-4">
            <QrCode className="w-5 h-5 text-primary" />
            <h2 className="font-bold text-dark">Kutu QR Kodu</h2>
          </div>

          {bin.type === 'public' ? (
            /* Public type kutular: QR gösterilmez */
            <div className="flex flex-col items-center justify-center gap-3 py-8 text-center">
              <div className="w-14 h-14 bg-blue-100 rounded-2xl flex items-center justify-center">
                <QrCode className="w-7 h-7 text-blue-500" />
              </div>
              <p className="text-blue-600 font-semibold text-sm">Bu kutu topluma açıktır</p>
              <p className="text-xs text-gray-400">Topluma açık kutular için ayrı QR görsel bulunmamaktadır.</p>
            </div>
          ) : bin.qr_image_url ? (
            /* Private type: Supabase'deki QR görselini render et */
            <div className="flex flex-col items-center gap-4">
              <div ref={qrRef} className="relative p-3 bg-white border-2 border-gray-100 rounded-2xl">
                {/* Skeleton – görsel yüklenene kadar göster */}
                {!qrImageLoaded && !qrImageError && (
                  <div className="absolute inset-3 rounded-xl bg-gray-100 animate-pulse flex items-center justify-center" style={{ minWidth: 168, minHeight: 168 }}>
                    <QrCode className="w-10 h-10 text-gray-300" />
                  </div>
                )}
                <img
                  src={bin.qr_image_url}
                  alt={`${bin.name || bin.bin_id} QR Kodu`}
                  className={`w-44 h-44 object-contain rounded-xl transition-opacity duration-300 ${qrImageLoaded ? 'opacity-100' : 'opacity-0'}`}
                  onLoad={() => setQrImageLoaded(true)}
                  onError={() => { setQrImageError(true); setQrImageLoaded(true) }}
                />
                {qrImageError && (
                  <div className="w-44 h-44 flex flex-col items-center justify-center gap-2 text-center">
                    <AlertTriangle className="w-8 h-8 text-amber-400" />
                    <p className="text-xs text-gray-500 font-medium">QR Kod Yüklenmedi</p>
                  </div>
                )}
              </div>

              {/* İndirme / Yazdırma butonları */}
              <div className="flex gap-3 w-full">
                <button
                  onClick={downloadQR}
                  disabled={!qrImageLoaded || qrImageError}
                  className="flex-1 flex items-center justify-center gap-2 bg-primary text-white font-semibold py-2.5 rounded-xl hover:bg-primary-dark transition-colors text-sm disabled:opacity-40"
                >
                  <Download className="w-4 h-4" />
                  QR İndir
                </button>
                <button
                  onClick={printQR}
                  disabled={!qrImageLoaded || qrImageError}
                  className="flex-1 flex items-center justify-center gap-2 bg-gray-100 text-gray-700 font-semibold py-2.5 rounded-xl hover:bg-gray-200 transition-colors text-sm disabled:opacity-40"
                >
                  <Printer className="w-4 h-4" />
                  Yazdır
                </button>
              </div>

              <p className="text-xs text-gray-400 text-center">Taratıldığında bu kutunun detay sayfasına yönlendirir.</p>
            </div>
          ) : (
            /* qr_image_url boş / null */
            <div className="flex flex-col items-center justify-center gap-3 py-8 text-center">
              <div className="w-14 h-14 bg-amber-50 rounded-2xl flex items-center justify-center">
                <AlertTriangle className="w-7 h-7 text-amber-400" />
              </div>
              <p className="text-amber-600 font-semibold text-sm">QR Kod Yüklenmedi</p>
              <p className="text-xs text-gray-400">Bu kutu için henüz QR kod görseli tanımlanmamış.</p>
            </div>
          )}
        </div>
      </div>

      {/* Fotoğraf Modal */}
      {selectedImage && (
        <div
          className="fixed inset-0 bg-black/70 z-[9999] flex items-center justify-center p-4"
          onClick={() => setSelectedImage(null)}
        >
          <div
            className="bg-white rounded-2xl overflow-hidden max-w-md w-full shadow-2xl"
            onClick={e => e.stopPropagation()}
          >
            <div className="relative">
              <img
                src={selectedImage.image_url}
                alt={selectedImage.waste_type}
                className="w-full max-h-72 object-cover"
                onError={e => { e.target.src = 'https://via.placeholder.com/400x300?text=Görsel+Yok' }}
              />
              <button
                onClick={() => setSelectedImage(null)}
                className="absolute top-3 right-3 bg-black/50 text-white rounded-full p-1 hover:bg-black/70"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="p-5 space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-bold text-dark capitalize text-lg">{selectedImage.waste_type}</span>
                <span className="bg-primary/10 text-primary font-bold px-3 py-1 rounded-full text-sm">
                  %{Math.round((selectedImage.confidence ?? 0) * 100)} Güven
                </span>
              </div>
              <p className="text-xs text-gray-400">{formatDate(selectedImage.created_at)}</p>
            </div>
          </div>
        </div>
      )}

      {/* Görevlendirme Onay Modalı */}
      {showAssignModal && (
        <AssignModal
          onClose={() => setShowAssignModal(false)}
          onConfirm={handleAssignConfirm}
          loading={assigning}
        />
      )}

      {/* Görevlendirme Toast */}
      {showToast && <AssignToast onClose={() => setShowToast(false)} />}
    </div>
  )
}
