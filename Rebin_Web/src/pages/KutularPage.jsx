import { useState, useEffect, useRef, useCallback } from 'react'
import { LayoutGrid, AlertCircle, RefreshCw, Plus, X, ChevronDown, Check, Loader2 } from 'lucide-react'
import BinCard from '../components/BinCard'
import LoadingSpinner from '../components/LoadingSpinner'
import { fetchBins, verifyAndAddBin, fetchAllBinErrors } from '../services/supabase'
import { sortByOccupancy } from '../utils/binUtils'

// ── Yardımcı: ortalama doluluk ───────────────────────────────────────────────
function avgOccupancy(bin) {
  return (
    ((bin.occupancy_glass ?? 0) +
      (bin.occupancy_metal ?? 0) +
      (bin.occupancy_paper ?? 0) +
      (bin.occupancy_plastic ?? 0)) /
    4
  )
}

// ── Filtre seçenekleri ────────────────────────────────────────────────────────
const OCCUPANCY_OPTIONS = [
  { label: 'Doluluğa göre filtrele', value: 'all' },
  { label: 'Kritik (≥ %85)', value: 'critical' },
  { label: 'Yüksek (≥ %75)', value: 'high' },
  { label: 'Orta (≥ %50)', value: 'mid' },
  { label: 'Düşük (< %50)', value: 'low' },
]

const DATE_OPTIONS = [
  { label: 'Güncelleme tarihine göre filtrele', value: 'all' },
  { label: 'En yeni önce', value: 'newest' },
  { label: 'En eski önce', value: 'oldest' },
]

// ── Açılır filtre bileşeni ────────────────────────────────────────────────────
function FilterDropdown({ options, value, onChange }) {
  const [open, setOpen] = useState(false)
  const ref = useRef(null)

  useEffect(() => {
    const handler = (e) => {
      if (ref.current && !ref.current.contains(e.target)) setOpen(false)
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  const selected = options.find((o) => o.value === value)
  const isFiltered = value !== 'all' && value !== options[0].value

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((p) => !p)}
        className={`flex items-center gap-1.5 text-sm font-medium border px-3 py-2 rounded-xl shadow-sm transition-all whitespace-nowrap ${isFiltered
            ? 'bg-primary/10 text-primary border-primary/30'
            : 'bg-white text-gray-600 hover:bg-gray-50 border-gray-200'
          }`}
      >
        {selected?.label ?? options[0].label}
        <ChevronDown className={`w-3.5 h-3.5 transition-transform ${open ? 'rotate-180' : ''}`} />
      </button>
      {open && (
        <div className="absolute top-full mt-1.5 left-0 z-50 bg-white border border-gray-100 rounded-xl shadow-lg min-w-[210px] py-1">
          {options.map((opt) => (
            <button
              key={opt.value}
              onClick={() => { onChange(opt.value); setOpen(false) }}
              className={`w-full text-left px-4 py-2 text-sm flex items-center gap-2 transition-colors hover:bg-gray-50 ${opt.value === value ? 'text-primary font-semibold' : 'text-gray-700'
                }`}
            >
              {opt.value === value
                ? <Check className="w-3.5 h-3.5 shrink-0" />
                : <span className="w-3.5 h-3.5 shrink-0" />}
              {opt.label}
            </button>
          ))}
        </div>
      )}
    </div>
  )
}

// ── Kutu Ekle Modalı ──────────────────────────────────────────────────────────
function AddBinModal({ onClose, onAdd }) {
  const [binId, setBinId] = useState('')
  const [qrToken, setQrToken] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState(null)

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!binId.trim() || !qrToken.trim()) {
      setError('Lütfen tüm alanları doldurun.')
      return
    }
    setLoading(true)
    setError(null)
    try {
      const bin = await verifyAndAddBin(binId.trim(), qrToken.trim())
      onAdd(bin)
      onClose()
    } catch (err) {
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    const handler = (e) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', handler)
    return () => document.removeEventListener('keydown', handler)
  }, [onClose])

  return (
    <div
      className="fixed inset-0 z-[9999] flex items-center justify-center bg-black/50 backdrop-blur-sm p-4"
      onClick={onClose}
    >
      <div
        className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden"
        onClick={(e) => e.stopPropagation()}
        style={{ animation: 'modalPop 0.22s cubic-bezier(.34,1.56,.64,1) both' }}
      >
        <div className="h-1 w-full bg-gradient-to-r from-green-400 to-emerald-500" />

        <div className="flex items-center justify-between px-6 pt-5 pb-4">
          <div className="flex items-center gap-2">
            <div className="w-9 h-9 bg-green-100 rounded-xl flex items-center justify-center">
              <Plus className="w-5 h-5 text-green-600" />
            </div>
            <h2 className="text-lg font-bold text-dark">Yeni Kutu Ekle</h2>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-gray-400 hover:bg-gray-100 hover:text-gray-600 transition-colors"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="px-6 pb-6 space-y-4">
          <p className="text-sm text-gray-500">
            Kutunun <strong>Kutu ID</strong> ve <strong>Güvenlik Kodu</strong>'nu girerek sisteme ekleyin.
          </p>

          <div className="space-y-1.5">
            <label className="block text-sm font-semibold text-gray-700">
              Kutu ID <span className="text-red-400">*</span>
            </label>
            <input
              type="text"
              value={binId}
              onChange={(e) => setBinId(e.target.value)}
              placeholder="Örn: BIN-0012"
              autoFocus
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-400 focus:border-transparent text-sm transition-all"
            />
          </div>

          <div className="space-y-1.5">
            <label className="block text-sm font-semibold text-gray-700">
              Güvenlik Kodu <span className="text-red-400">*</span>
            </label>
            <input
              type="password"
              value={qrToken}
              onChange={(e) => setQrToken(e.target.value)}
              placeholder="QR token / güvenlik kodu"
              className="w-full px-4 py-2.5 rounded-xl border border-gray-200 focus:outline-none focus:ring-2 focus:ring-green-400 focus:border-transparent text-sm transition-all"
            />
          </div>

          {error && (
            <div className="flex items-start gap-2 bg-red-50 border border-red-100 rounded-xl px-4 py-3">
              <AlertCircle className="w-4 h-4 text-red-500 mt-0.5 shrink-0" />
              <p className="text-sm text-red-600">{error}</p>
            </div>
          )}

          <div className="flex gap-3 pt-1">
            <button
              type="button"
              onClick={onClose}
              className="flex-1 py-2.5 rounded-xl border border-gray-200 text-sm font-medium text-gray-600 hover:bg-gray-50 transition-colors"
            >
              İptal
            </button>
            <button
              type="submit"
              disabled={loading}
              className="flex-1 py-2.5 rounded-xl bg-green-500 hover:bg-green-600 text-white text-sm font-semibold transition-colors flex items-center justify-center gap-2 disabled:opacity-60"
            >
              {loading
                ? <><Loader2 className="w-4 h-4 animate-spin" /> Doğrulanıyor...</>
                : <><Plus className="w-4 h-4" /> Kutuyu Ekle</>}
            </button>
          </div>
        </form>
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

// ── Ana Sayfa ─────────────────────────────────────────────────────────────────
export default function KutularPage() {
  const [bins, setBins] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [showModal, setShowModal] = useState(false)
  // bin_id -> {error_1, error_2, error_3, error_4} haritası
  const [errorsMap, setErrorsMap] = useState({})

  const [occupancyFilter, setOccupancyFilter] = useState('all')
  const [dateFilter, setDateFilter] = useState('all')
  const [semtFilter, setSemtFilter] = useState('all')

  const loadBins = async () => {
    try {
      setLoading(true)
      setError(null)
      const [data, errorsData] = await Promise.all([
        fetchBins(),
        fetchAllBinErrors(),
      ])
      // bin_id -> hata objesi eşleşmesi
      const map = {}
      errorsData.forEach((e) => { map[e.bin_id] = e })
      setErrorsMap(map)
      setBins(sortByOccupancy(data, map))
    } catch (err) {
      console.error('Kutular yüklenemedi:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { loadBins() }, [])

  const handleAddBin = useCallback((bin) => {
    setBins((prev) => {
      if (prev.some((b) => b.bin_id === bin.bin_id)) return prev
      return sortByOccupancy([...prev, bin], errorsMap)
    })
  }, [errorsMap])

  // Semte göre filtre seçenekleri (DB'den dinamik)
  const semtOptions = [
    { label: 'Semte göre filtrele', value: 'all' },
    ...Array.from(new Set(bins.map((b) => b.semt).filter(Boolean)))
      .sort()
      .map((s) => ({ label: s, value: s })),
  ]

  // Filtrele + sırala
  const filteredBins = bins
    .filter((bin) => {
      const avg = avgOccupancy(bin)
      if (occupancyFilter === 'critical') return avg >= 0.85
      if (occupancyFilter === 'high') return avg >= 0.75
      if (occupancyFilter === 'mid') return avg >= 0.5
      if (occupancyFilter === 'low') return avg < 0.5
      return true
    })
    .filter((bin) => semtFilter === 'all' || bin.semt === semtFilter)
    .sort((a, b) => {
      if (dateFilter === 'newest') return new Date(b.last_updated) - new Date(a.last_updated)
      if (dateFilter === 'oldest') return new Date(a.last_updated) - new Date(b.last_updated)
      return 0
    })

  return (
    <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 page-enter">
      {/* Başlık */}
      <div className="flex items-center justify-between mb-6 flex-wrap gap-3">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center">
            <LayoutGrid className="w-5 h-5 text-primary" />
          </div>
          <div>
            <h1 className="text-2xl font-bold text-dark">Rebin Kutuları</h1>
            <p className="text-sm text-gray-500">
              {loading
                ? 'Yükleniyor...'
                : `${filteredBins.length} / ${bins.length} kutu gösteriliyor`}
            </p>
          </div>
        </div>

        {/* Sağ: filtreler + butonlar */}
        <div className="flex items-center gap-2 flex-wrap">
          <FilterDropdown
            options={OCCUPANCY_OPTIONS}
            value={occupancyFilter}
            onChange={setOccupancyFilter}
          />
          <FilterDropdown
            options={DATE_OPTIONS}
            value={dateFilter}
            onChange={setDateFilter}
          />
          <FilterDropdown
            options={semtOptions}
            value={semtFilter}
            onChange={setSemtFilter}
          />

          {/* +KUTU EKLE */}
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-1.5 text-sm font-semibold text-white bg-green-500 hover:bg-green-600 active:bg-green-700 px-4 py-2 rounded-xl shadow-sm transition-all"
          >
            <Plus className="w-4 h-4" />
            KUTU EKLE
          </button>

          {/* Yenile */}
          <button
            onClick={loadBins}
            disabled={loading}
            className="flex items-center gap-2 text-sm font-medium text-gray-600 bg-white hover:bg-gray-50 border border-gray-200 px-4 py-2 rounded-xl shadow-sm transition-all disabled:opacity-50"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Yenile
          </button>
        </div>
      </div>

      {/* İstatistik Özet Kartları */}
      {!loading && !error && bins.length > 0 && (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
          {[
            { label: 'Toplam Kutu', value: bins.length, color: 'text-dark' },
            { label: 'Aktif', value: bins.filter((b) => b.is_active).length, color: 'text-green-600' },
            { label: 'Kritik (≥%85)', value: bins.filter((b) => avgOccupancy(b) >= 0.85).length, color: 'text-red-500' },
            { label: 'Boşaltım Gerekli (≥%75)', value: bins.filter((b) => avgOccupancy(b) >= 0.75).length, color: 'text-amber-500' },
          ].map((stat) => (
            <div key={stat.label} className="bg-white rounded-2xl shadow-card border border-gray-100 p-4 text-center">
              <p className={`text-3xl font-bold ${stat.color}`}>{stat.value}</p>
              <p className="text-xs text-gray-500 mt-1">{stat.label}</p>
            </div>
          ))}
        </div>
      )}

      {/* Yükleme / Hata / Liste */}
      {loading && <LoadingSpinner text="Kutular yükleniyor..." />}

      {error && (
        <div className="flex flex-col items-center justify-center py-16 gap-4">
          <div className="w-14 h-14 bg-red-100 rounded-2xl flex items-center justify-center">
            <AlertCircle className="w-7 h-7 text-red-500" />
          </div>
          <div className="text-center">
            <p className="font-semibold text-dark">Veriler yüklenemedi</p>
            <p className="text-sm text-gray-500 mt-1">{error}</p>
          </div>
          <button
            onClick={loadBins}
            className="bg-primary text-white px-6 py-2.5 rounded-xl text-sm font-semibold hover:bg-primary-dark transition-colors"
          >
            Tekrar Dene
          </button>
        </div>
      )}

      {!loading && !error && filteredBins.length === 0 && (
        <div className="text-center py-16">
          <p className="text-gray-400 text-lg">
            {bins.length === 0
              ? 'Henüz hiç kutu eklenmemiş.'
              : 'Seçilen filtrelere uyan kutu bulunamadı.'}
          </p>
        </div>
      )}

      {!loading && !error && filteredBins.length > 0 && (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-5">
          {filteredBins.map((bin) => (
            <BinCard key={bin.bin_id} bin={bin} binErrors={errorsMap[bin.bin_id] ?? null} />
          ))}
        </div>
      )}

      {/* Kutu Ekle Modalı */}
      {showModal && (
        <AddBinModal
          onClose={() => setShowModal(false)}
          onAdd={handleAddBin}
        />
      )}
    </div>
  )
}
