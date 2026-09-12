import { useState, useEffect, useRef, useCallback } from 'react'
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet'
import L from 'leaflet'
import { useNavigate, useSearchParams } from 'react-router-dom'
import { AlertCircle, Navigation, MapPin, Building2, Package, ChevronDown } from 'lucide-react'
import { calcOccupancy, toPercent, CITIES, DEPOTS, FACILITIES } from '../utils/binUtils'
import LoadingSpinner from '../components/LoadingSpinner'
import CitySelector from '../components/CitySelector'
import { useSimulation } from '../context/SimulationContext'
import { fetchAllBinErrors } from '../services/supabase'

// ─── Marker İkon Fabrikaları ────────────────────────────────────────────────

function createBinIcon(type, occupancy, faulty = false) {
  const color = type === 'private' ? '#38A169' : '#2196F3'
  const fill = faulty
    ? '#D97706'
    : occupancy === 0 ? '#10B981'
    : occupancy >= 0.85 ? '#EF5350'
    : occupancy >= 0.65 ? '#FFCA28'
    : color

  const faultBadge = faulty
    ? `<circle cx="30" cy="6" r="7" fill="#EF5350" stroke="white" stroke-width="1.5"/>
       <text x="30" y="10.5" text-anchor="middle" font-size="10" font-weight="900" fill="white">!</text>`
    : ''

  const label = occupancy === 0 ? '\u2713' : Math.round(occupancy * 100) + '%'
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="36" height="48" viewBox="0 0 36 48">
      <path d="M18 0 C8.06 0 0 8.06 0 18 C0 31 18 48 18 48 C18 48 36 31 36 18 C36 8.06 27.94 0 18 0Z" fill="${fill}" stroke="white" stroke-width="2"/>
      <circle cx="18" cy="18" r="9" fill="white" opacity="0.9"/>
      <text x="18" y="22" text-anchor="middle" font-size="${occupancy === 0 ? '11' : '9'}" font-weight="bold" fill="${fill}">${label}</text>
      ${faultBadge}
    </svg>
  `
  return L.divIcon({
    html: svg,
    className: '',
    iconSize: [36, 48],
    iconAnchor: [18, 48],
    popupAnchor: [0, -50],
  })
}

// Mavi Depo İkonu (DB'den gelen depolar için)
function createDepotIcon(name, color = '#1D4ED8') {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="48" viewBox="0 0 40 48">
      <rect x="2" y="14" width="36" height="28" rx="5" fill="${color}" stroke="white" stroke-width="2"/>
      <polygon points="20,2 38,14 2,14" fill="${color}" stroke="white" stroke-width="2" stroke-linejoin="round"/>
      <rect x="14" y="26" width="12" height="16" rx="2" fill="white" opacity="0.9"/>
      <rect x="16" y="20" width="8" height="8" rx="1.5" fill="white" opacity="0.7"/>
    </svg>
  `
  return L.divIcon({
    html: `<div style="display:flex;flex-direction:column;align-items:center;gap:2px;">
      ${svg}
      <div style="background:${color};color:white;border-radius:6px;padding:2px 6px;font-size:10px;font-weight:700;border:1.5px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.25);white-space:nowrap;max-width:120px;overflow:hidden;text-overflow:ellipsis;">${name}</div>
    </div>`,
    className: '',
    iconSize: [40, 72],
    iconAnchor: [20, 72],
    popupAnchor: [0, -74],
  })
}

// Yeşil Tesis İkonu (DB'den gelen tesisler için)
function createTesisIcon(name, color = '#15803D') {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="48" viewBox="0 0 40 48">
      <circle cx="20" cy="22" r="18" fill="${color}" stroke="white" stroke-width="2"/>
      <text x="20" y="28" text-anchor="middle" font-size="20">♻️</text>
    </svg>
  `
  return L.divIcon({
    html: `<div style="display:flex;flex-direction:column;align-items:center;gap:2px;">
      ${svg}
      <div style="background:${color};color:white;border-radius:6px;padding:2px 6px;font-size:10px;font-weight:700;border:1.5px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.25);white-space:nowrap;max-width:120px;overflow:hidden;text-overflow:ellipsis;">${name}</div>
    </div>`,
    className: '',
    iconSize: [40, 72],
    iconAnchor: [20, 72],
    popupAnchor: [0, -74],
  })
}

// Statik fallback ikonları (Depolar)
const staticDepotIcon = (depotKey, depot) => L.divIcon({
  html: `
    <div style="background:${depot?.color || '#2563EB'};color:white;border-radius:8px;padding:4px 8px;font-size:11px;font-weight:700;border:2px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.3);white-space:nowrap;display:flex;align-items:center;gap:4px;">
      <span>&#127968;</span>
      <span>${depot?.shortName || depotKey}</span>
    </div>
  `,
  className: '',
  iconSize: [null, null],
  iconAnchor: [30, 15],
})

// Statik fallback ikonları (Tesisler)
const staticFacilityIcon = (facility) => L.divIcon({
  html: `
    <div style="background:${facility.color || '#7C3AED'};color:white;border-radius:10px;padding:4px 8px;font-size:11px;font-weight:700;border:2px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.35);white-space:nowrap;display:flex;align-items:center;gap:4px;">
      <span>&#127981;</span>
      <span>${facility.shortName || facility.name}</span>
    </div>
  `,
  className: '',
  iconSize: [null, null],
  iconAnchor: [40, 15],
})

const depotTruckIcon = (depot) => {
  const color = depot?.color || '#2563EB'
  return L.divIcon({
    html: `
      <div style="display:flex;flex-direction:column;align-items:center;transform:translate(-50%, -50%);">
        <div style="font-size:28px;filter:drop-shadow(0 3px 6px rgba(0,0,0,0.4));">${depot?.truckEmoji || ''}</div>
        <div style="background:${color};color:white;font-size:9px;font-weight:bold;padding:1px 5px;border-radius:6px;border:1.5px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.25);white-space:nowrap;">
          ${depot?.shortName || 'Arac'}
        </div>
      </div>
    `,
    className: '',
    iconSize: [0, 0],
    iconAnchor: [0, 0],
  })
}

// ─── Leaflet Hook Bileşenleri ───────────────────────────────────────────────

function FlyToBin({ bin }) {
  const map = useMap()
  useEffect(() => {
    if (bin && bin.latitude && bin.longitude) {
      map.flyTo([bin.latitude, bin.longitude], 16, { duration: 1.2 })
    }
  }, [bin, map])
  return null
}

function FlyToTarget({ target }) {
  const map = useMap()
  useEffect(() => {
    if (target && typeof target.lat === 'number' && typeof target.lng === 'number') {
      map.flyTo([target.lat, target.lng], target.zoom || 15, { duration: 1.2 })
    }
  }, [target, map])
  return null
}

function MapController({ city }) {
  const map = useMap()
  const prevCity = useRef(null)
  useEffect(() => {
    if (city !== prevCity.current) {
      prevCity.current = city
      const cfg = CITIES[city] || CITIES.istanbul
      map.setView(cfg.center, cfg.zoom || 12, { animate: true, duration: 1 })
    }
  }, [city, map])
  return null
}

// ─── Marker Popup Açma Yardımcısı ─────────────────────────────────────────

function OpenPopup({ markerRef }) {
  const map = useMap()
  useEffect(() => {
    if (markerRef?.current) {
      markerRef.current.openPopup()
    }
  }, [markerRef, map])
  return null
}

// ─── Ana Sayfa ─────────────────────────────────────────────────────────────

export default function HaritaPage() {
  const {
    bins,
    loadingBins: loading,
    binsError: error,
    selectedCity,
    setSelectedCity,
    routes,
    dbDepolar,
    dbTesisler,
    dbLoading,
  } = useSimulation()

  const [targetBin, setTargetBin] = useState(null)
  const [searchParams] = useSearchParams()
  const [errorsMap, setErrorsMap] = useState({})
  const navigate = useNavigate()

  // Harita Modülü State'leri
  const [activeTab, setActiveTab] = useState('depolar')  // 'depolar' | 'tesisler'
  const [semtFilter, setSemtFilter] = useState('all')
  const [flyTarget, setFlyTarget] = useState(null)
  const [showSemtDropdown, setShowSemtDropdown] = useState(false)
  const semtDropdownRef = useRef(null)

  // Marker ref map'leri (popup açmak için)
  const markerRefs = useRef({})
  const [activeMarkerKey, setActiveMarkerKey] = useState(null)

  useEffect(() => {
    const binId = searchParams.get('binId')
    if (binId && bins.length > 0) {
      const found = bins.find(b => b.bin_id === binId)
      if (found) setTargetBin(found)
    }
  }, [searchParams, bins])

  // bin_errors verilerini çek
  useEffect(() => {
    fetchAllBinErrors()
      .then(data => {
        const map = {}
        data.forEach(e => { map[e.bin_id] = e })
        setErrorsMap(map)
      })
      .catch(console.error)
  }, [])

  // Şehir değişince semt filtresini sıfırla
  useEffect(() => {
    setSemtFilter('all')
    setFlyTarget(null)
    setActiveMarkerKey(null)
  }, [selectedCity])

  // Dışarı tıklanınca dropdown kapat
  useEffect(() => {
    const handleOut = (e) => {
      if (semtDropdownRef.current && !semtDropdownRef.current.contains(e.target)) {
        setShowSemtDropdown(false)
      }
    }
    document.addEventListener('mousedown', handleOut)
    return () => document.removeEventListener('mousedown', handleOut)
  }, [])

  // ── Gösterilecek veriler ──────────────────────────────────────────────────

  // Depo ve tesisleri DB'den al; yoksa statik fallback
  const hasDbDepolar = dbDepolar.length > 0
  const hasDbTesisler = dbTesisler.length > 0

  // Semt seçenekleri
  const depotSemtOptions = hasDbDepolar
    ? Array.from(new Set(dbDepolar.map(d => d.semt).filter(Boolean))).sort()
    : Array.from(new Set(Object.values(DEPOTS).filter(d => d.city === selectedCity).map(d => d.shortName).filter(Boolean))).sort()

  const tesisSemtOptions = hasDbTesisler
    ? Array.from(new Set(dbTesisler.map(t => t.semt).filter(Boolean))).sort()
    : Array.from(new Set(FACILITIES.filter(f => f.city === selectedCity).map(f => f.region).filter(Boolean))).sort()

  const semtOptions = activeTab === 'depolar' ? depotSemtOptions : tesisSemtOptions

  // Filtrelenmiş listeler (kart listesi için)
  const filteredDepolar = hasDbDepolar
    ? dbDepolar.filter(d => semtFilter === 'all' || d.semt === semtFilter)
    : Object.entries(DEPOTS)
        .filter(([, d]) => d.city === selectedCity)
        .filter(([, d]) => semtFilter === 'all' || d.shortName === semtFilter)
        .map(([key, d]) => ({
          id: key,
          depo_adi: d.name,
          semt: d.shortName,
          city: selectedCity,
          latitude: d.lat,
          longitude: d.lng,
          _isStatic: true,
          _color: d.color,
        }))

  const filteredTesisler = hasDbTesisler
    ? dbTesisler.filter(t => semtFilter === 'all' || t.semt === semtFilter)
    : FACILITIES
        .filter(f => f.city === selectedCity)
        .filter(f => semtFilter === 'all' || f.region === semtFilter)
        .map(f => ({
          id: f.id,
          tesis_adi: f.name,
          semt: f.region || f.shortName,
          city: selectedCity,
          latitude: f.lat,
          longitude: f.lng,
          _isStatic: true,
          _color: f.color,
        }))

  // Aktif rotalar
  const activeRoutes = Object.entries(routes).filter(([, r]) => r && r.routeCoords && r.routeCoords.length > 0)
  const anyTruckMoving = Object.values(routes).some(r => r.isPlaying)

  // Karta tıklandığında haritayı o koordinata taşı
  const handleCardClick = useCallback((item, type) => {
    const lat = item.latitude
    const lng = item.longitude
    if (typeof lat !== 'number' || typeof lng !== 'number') return
    const key = `${type}_${item.id}`
    setFlyTarget({ lat, lng, zoom: 15 })
    setActiveMarkerKey(key)
  }, [])

  // ── Loading / Error durumları ─────────────────────────────────────────────

  if (loading) return (
    <div className="max-w-7xl mx-auto px-4 py-8">
      <LoadingSpinner text="Harita yükleniyor..." />
    </div>
  )

  if (error) return (
    <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
      <AlertCircle className="w-12 h-12 text-red-400" />
      <p className="text-gray-600">Veriler yüklenemedi: {error}</p>
    </div>
  )

  // ── Render ────────────────────────────────────────────────────────────────

  return (
    <div className="flex flex-col h-[calc(100vh-64px)]">

      {/* ── Üst Araç Çubuğu ── */}
      <div className="bg-white border-b border-gray-200 px-4 sm:px-6 py-3 flex items-center justify-between gap-4 flex-wrap z-10">
        <div>
          <h1 className="text-lg font-bold text-dark">Harita Görünümü</h1>
          <p className="text-xs text-gray-500">
            {bins.length} kayıtlı kutu
            {hasDbDepolar && ` · ${dbDepolar.length} depo`}
            {hasDbTesisler && ` · ${dbTesisler.length} tesis`}
            {activeRoutes.length > 0 && ` · ${activeRoutes.length} aktif rota`}
          </p>
        </div>

        <div className="flex items-center gap-3 flex-wrap">
          {/* Şehir Seçici */}
          <div className="flex items-center gap-2">
            <span className="text-xs font-semibold text-gray-500 hidden sm:inline">Şehir:</span>
            <CitySelector selectedCity={selectedCity} onSelectCity={setSelectedCity} />
          </div>

          {/* Semt Filtresi */}
          <div className="relative" ref={semtDropdownRef}>
            <button
              type="button"
              onClick={() => setShowSemtDropdown(v => !v)}
              className="flex items-center gap-1.5 bg-white hover:bg-gray-50 border border-gray-200 px-3 py-2 rounded-xl text-xs font-semibold text-gray-700 shadow-sm transition-all"
            >
              <MapPin className="w-3.5 h-3.5 text-gray-400" />
              <span>{semtFilter === 'all' ? 'Tüm Semtler' : semtFilter}</span>
              <ChevronDown className={`w-3 h-3 text-gray-400 transition-transform ${showSemtDropdown ? 'rotate-180' : ''}`} />
            </button>
            {showSemtDropdown && (
              <div className="absolute top-full right-0 mt-1.5 w-48 bg-white border border-gray-100 rounded-2xl shadow-xl py-1.5 z-[1001]">
                <button
                  type="button"
                  onClick={() => { setSemtFilter('all'); setShowSemtDropdown(false) }}
                  className={`w-full text-left px-3.5 py-2 text-xs font-medium transition-colors ${semtFilter === 'all' ? 'bg-primary/10 text-primary font-bold' : 'text-gray-700 hover:bg-gray-50'}`}
                >
                  Tüm Semtler
                </button>
                {semtOptions.map(s => (
                  <button
                    key={s}
                    type="button"
                    onClick={() => { setSemtFilter(s); setShowSemtDropdown(false) }}
                    className={`w-full text-left px-3.5 py-2 text-xs font-medium transition-colors ${semtFilter === s ? 'bg-primary/10 text-primary font-bold' : 'text-gray-700 hover:bg-gray-50'}`}
                  >
                    {s}
                  </button>
                ))}
              </div>
            )}
          </div>

          {/* Lejant */}
          <div className="hidden md:flex items-center gap-4 text-xs text-gray-600 bg-gray-50 px-3 py-1.5 rounded-xl border border-gray-100">
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-sm bg-[#1D4ED8] inline-block" />
              Depo
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-[#15803D] inline-block" />
              Tesis
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-[#38A169] inline-block" />
              Özel Kutu
            </span>
            <span className="flex items-center gap-1.5">
              <span className="w-2.5 h-2.5 rounded-full bg-[#EF5350] inline-block" />
              Arızalı
            </span>
            {anyTruckMoving && (
              <span className="flex items-center gap-1 font-semibold text-primary animate-pulse">
                <Navigation className="w-3 h-3" /> Canlı Filo Aktif
              </span>
            )}
          </div>
        </div>
      </div>

      {/* ── Ana İçerik: Harita + Yan Panel ── */}
      <div className="flex flex-1 overflow-hidden">

        {/* ── Harita ── */}
        <div className="flex-1 relative">
          {dbLoading && (
            <div className="absolute top-3 left-1/2 -translate-x-1/2 z-[1000] bg-white/90 backdrop-blur-sm border border-gray-200 text-xs text-gray-600 px-3 py-1.5 rounded-full shadow-md flex items-center gap-2">
              <span className="w-3 h-3 border-2 border-primary border-t-transparent rounded-full animate-spin" />
              Depo/Tesis verileri yükleniyor...
            </div>
          )}

          <MapContainer
            center={CITIES[selectedCity]?.center || CITIES.istanbul.center}
            zoom={CITIES[selectedCity]?.zoom || 12}
            style={{ height: '100%', width: '100%' }}
            className="z-0"
          >
            <TileLayer
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />

            {/* Şehir değişince uç */}
            <MapController city={selectedCity} />

            {/* FlyTo: Kart listesinden tıklamada */}
            <FlyToTarget target={flyTarget} />

            {/* FlyTo: URL'den gelen bin */}
            {targetBin && <FlyToBin bin={targetBin} />}

            {/* ── DB Depo Markerları ── */}
            {hasDbDepolar && dbDepolar
              .filter(d => semtFilter === 'all' || d.semt === semtFilter)
              .map(depo => {
                if (typeof depo.latitude !== 'number' || typeof depo.longitude !== 'number') return null
                const key = `depolar_${depo.id}`
                return (
                  <Marker
                    key={key}
                    position={[depo.latitude, depo.longitude]}
                    icon={createDepotIcon(depo.depo_adi, '#1D4ED8')}
                    ref={el => { if (el) markerRefs.current[key] = el }}
                  >
                    <Popup>
                      <div style={{ minWidth: 160, fontFamily: 'sans-serif' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                          <span style={{ fontSize: 18 }}>🏠</span>
                          <p style={{ fontWeight: 700, fontSize: 13, color: '#1D4ED8', margin: 0 }}>{depo.depo_adi}</p>
                        </div>
                        <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 2px' }}>
                          📍 {depo.semt} / {depo.city}
                        </p>
                        <span style={{ fontSize: 10, background: '#EFF6FF', color: '#1D4ED8', padding: '2px 8px', borderRadius: 99, fontWeight: 700 }}>
                          Toplama Deposu
                        </span>
                      </div>
                    </Popup>
                  </Marker>
                )
              })}

            {/* ── DB Tesis Markerları ── */}
            {hasDbTesisler && dbTesisler
              .filter(t => semtFilter === 'all' || t.semt === semtFilter)
              .map(tesis => {
                if (typeof tesis.latitude !== 'number' || typeof tesis.longitude !== 'number') return null
                const key = `tesisler_${tesis.id}`
                return (
                  <Marker
                    key={key}
                    position={[tesis.latitude, tesis.longitude]}
                    icon={createTesisIcon(tesis.tesis_adi, '#15803D')}
                    ref={el => { if (el) markerRefs.current[key] = el }}
                  >
                    <Popup>
                      <div style={{ minWidth: 160, fontFamily: 'sans-serif' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                          <span style={{ fontSize: 18 }}>♻️</span>
                          <p style={{ fontWeight: 700, fontSize: 13, color: '#15803D', margin: 0 }}>{tesis.tesis_adi}</p>
                        </div>
                        <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 2px' }}>
                          📍 {tesis.semt} / {tesis.city}
                        </p>
                        <span style={{ fontSize: 10, background: '#F0FDF4', color: '#15803D', padding: '2px 8px', borderRadius: 99, fontWeight: 700 }}>
                          Geri Dönüşüm Tesisi
                        </span>
                      </div>
                    </Popup>
                  </Marker>
                )
              })}

            {/* ── Statik Fallback Depo Markerları (DB boşsa) ── */}
            {!hasDbDepolar && Object.entries(DEPOTS)
              .filter(([, d]) => d.city === selectedCity)
              .map(([key, depot]) => (
                <Marker
                  key={`static_depot_${key}`}
                  position={[depot.lat, depot.lng]}
                  icon={staticDepotIcon(key, depot)}
                >
                  <Popup>
                    <div className="text-center font-sans">
                      <p className="font-bold text-dark text-sm">{depot.name}</p>
                      <p className="text-xs text-gray-500 mt-0.5">Toplama Deposu ({depot.city === 'ankara' ? 'Ankara' : 'İstanbul'})</p>
                    </div>
                  </Popup>
                </Marker>
              ))}

            {/* ── Statik Fallback Tesis Markerları (DB boşsa) ── */}
            {!hasDbTesisler && FACILITIES
              .filter(f => f.city === selectedCity)
              .map((fac) => (
                <Marker
                  key={`static_fac_${fac.id}`}
                  position={[fac.lat, fac.lng]}
                  icon={staticFacilityIcon(fac)}
                >
                  <Popup>
                    <div className="text-center font-sans">
                      <p className="font-bold text-purple-700 text-sm">&#127981; {fac.name}</p>
                      <p className="text-xs text-gray-500 mt-0.5">{fac.region || fac.city}</p>
                      <p className="text-xs text-gray-400 mt-0.5">Geri Dönüşüm &amp; Ayırma Merkezi</p>
                    </div>
                  </Popup>
                </Marker>
              ))}

            {/* ── Kutu Markerları ── */}
            {bins.map(bin => {
              if (typeof bin.latitude !== 'number' || typeof bin.longitude !== 'number') return null
              const occ = calcOccupancy(bin)
              const binErr = errorsMap[bin.bin_id]
              const isFaulty =
                bin.status === 'out_of_order' ||
                (binErr && (
                  (binErr.error_1 ?? 0) > 0 ||
                  (binErr.error_2 ?? 0) > 0 ||
                  (binErr.error_3 ?? 0) > 0 ||
                  (binErr.error_4 ?? 0) > 0
                ))
              const icon = createBinIcon(bin.type, occ, isFaulty)
              const isSimulated = !bin.bin_id || String(bin.bin_id).startsWith('sim_')

              const statusBadge = isFaulty
                ? { label: 'ARIZALI !', bg: '#FEF08A', color: '#92400E', border: '#D97706' }
                : bin.is_active
                  ? { label: 'Aktif', bg: '#DCFCE7', color: '#166534', border: '#22C55E' }
                  : { label: 'Deaktif', bg: '#F1F5F9', color: '#64748B', border: '#94A3B8' }

              return (
                <Marker
                  key={bin.bin_id ?? `bin_${Math.random()}`}
                  position={[bin.latitude, bin.longitude]}
                  icon={icon}
                >
                  <Popup>
                    <div style={{ minWidth: 170, fontFamily: 'sans-serif' }}>
                      <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between', gap: 8, marginBottom: 4 }}>
                        <div>
                          <p style={{ fontWeight: 700, fontSize: 13, color: '#1a1a2e', margin: 0, lineHeight: 1.3 }}>{bin.name || bin.bin_id}</p>
                          <p style={{ fontSize: 10, color: '#9CA3AF', fontFamily: 'monospace', margin: 0 }}>{bin.bin_id}</p>
                        </div>
                        <span style={{
                          fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 99,
                          background: statusBadge.bg, color: statusBadge.color,
                          border: `1.5px solid ${statusBadge.border}`, whiteSpace: 'nowrap', flexShrink: 0,
                        }}>
                          {statusBadge.label}
                        </span>
                      </div>

                      {bin.semt && (
                        <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 4px' }}>&#128205; {bin.semt}</p>
                      )}

                      <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 8 }}>
                        <div style={{
                          color: 'white', fontSize: 11, fontWeight: 700, padding: '2px 8px', borderRadius: 99,
                          backgroundColor: isFaulty ? '#D97706' : occ === 0 ? '#10B981' : occ >= 0.85 ? '#EF5350' : occ >= 0.65 ? '#FFCA28' : '#38A169',
                        }}>
                          {occ === 0 ? '\u2713 Temizlendi' : `${toPercent(occ)} Dolu`}
                        </div>
                        <span style={{ fontSize: 11, color: '#6B7280' }}>
                          {bin.type === 'private' ? 'Özel' : 'Topluma Açık'}
                        </span>
                      </div>

                      {!isSimulated && (
                        <button
                          onClick={() => navigate(`/bin/${bin.bin_id}`)}
                          style={{
                            marginTop: 8, width: '100%', fontSize: 11, color: '#38A169',
                            fontWeight: 700, border: '1px solid rgba(56,161,105,0.3)',
                            borderRadius: 8, padding: '4px 0', background: 'transparent', cursor: 'pointer',
                          }}
                        >
                          Detayları Gör &#8594;
                        </button>
                      )}
                      {isSimulated && (
                        <p style={{ fontSize: 11, color: '#F59E0B', marginTop: 4, fontWeight: 500 }}>&#10024; Örnek Kutu</p>
                      )}
                    </div>
                  </Popup>
                </Marker>
              )
            })}

            {/* ── Rota ve Araç Markerları ── */}
            {activeRoutes.map(([depotKey, route]) => {
              const depotInfo = DEPOTS[depotKey] || {}
              const polyline = route.routeCoords.map(([lng, lat]) => [lat, lng])
              const routeColor = '#22C55E' // Her zaman açık yeşil
              return (
                <div key={depotKey}>
                  <Polyline positions={polyline} color={routeColor} weight={5} opacity={0.85} />
                  {route.truckPosition && (
                    <Marker
                      position={route.truckPosition}
                      icon={depotTruckIcon(depotInfo)}
                      zIndexOffset={1000}
                    >
                      <Popup>
                        <div className="text-center font-sans">
                          <p className="font-bold text-dark">{depotInfo.name || `${depotKey} Aracı`}</p>
                          <p className="text-xs text-gray-500 mt-0.5">İlerleme: %{Math.round(route.progress * 100)}</p>
                        </div>
                      </Popup>
                    </Marker>
                  )}
                </div>
              )
            })}
          </MapContainer>
        </div>

        {/* ── Yan Panel: Depolar / Tesisler Listesi ── */}
        <div className="w-80 min-w-[280px] bg-white border-l border-gray-200 flex flex-col overflow-hidden shadow-lg z-10">

          {/* Sekme Başlıkları */}
          <div className="flex border-b border-gray-200">
            <button
              type="button"
              onClick={() => { setActiveTab('depolar'); setSemtFilter('all') }}
              className={`flex-1 flex items-center justify-center gap-2 py-3 text-xs font-bold transition-colors border-b-2 ${
                activeTab === 'depolar'
                  ? 'border-blue-600 text-blue-700 bg-blue-50/50'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'
              }`}
            >
              <Building2 className="w-3.5 h-3.5" />
              Depolar
              <span className={`text-[10px] font-extrabold px-1.5 py-0.5 rounded-full ${activeTab === 'depolar' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-500'}`}>
                {filteredDepolar.length}
              </span>
            </button>
            <button
              type="button"
              onClick={() => { setActiveTab('tesisler'); setSemtFilter('all') }}
              className={`flex-1 flex items-center justify-center gap-2 py-3 text-xs font-bold transition-colors border-b-2 ${
                activeTab === 'tesisler'
                  ? 'border-green-600 text-green-700 bg-green-50/50'
                  : 'border-transparent text-gray-500 hover:text-gray-700 hover:bg-gray-50'
              }`}
            >
              <Package className="w-3.5 h-3.5" />
              Tesisler
              <span className={`text-[10px] font-extrabold px-1.5 py-0.5 rounded-full ${activeTab === 'tesisler' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-500'}`}>
                {filteredTesisler.length}
              </span>
            </button>
          </div>

          {/* Liste İçeriği */}
          <div className="flex-1 overflow-y-auto p-3 space-y-2">
            {dbLoading ? (
              <div className="flex flex-col items-center justify-center py-12 gap-3 text-gray-400">
                <span className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
                <p className="text-xs">Yükleniyor...</p>
              </div>
            ) : activeTab === 'depolar' ? (
              filteredDepolar.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 gap-2 text-gray-400">
                  <Building2 className="w-8 h-8 opacity-40" />
                  <p className="text-xs text-center">
                    {semtFilter === 'all'
                      ? `${CITIES[selectedCity]?.label || selectedCity} için depo bulunamadı.`
                      : `"${semtFilter}" semtinde depo yok.`}
                  </p>
                </div>
              ) : filteredDepolar.map(depo => (
                <button
                  key={`card_depolar_${depo.id}`}
                  type="button"
                  onClick={() => handleCardClick(depo, 'depolar')}
                  className="w-full text-left p-3 rounded-xl border border-gray-200 hover:border-blue-400 hover:bg-blue-50/40 transition-all group active:scale-[0.98] shadow-sm"
                >
                  <div className="flex items-start gap-2.5">
                    <div className="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center text-blue-700 shrink-0 mt-0.5 group-hover:bg-blue-200 transition-colors">
                      <Building2 className="w-4 h-4" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-xs text-dark truncate">{depo.depo_adi}</p>
                      <p className="text-[11px] text-gray-500 truncate mt-0.5">
                        📍 {depo.semt} / {depo.city}
                      </p>
                    </div>
                    <MapPin className="w-3.5 h-3.5 text-blue-400 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </div>
                </button>
              ))
            ) : (
              filteredTesisler.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-12 gap-2 text-gray-400">
                  <Package className="w-8 h-8 opacity-40" />
                  <p className="text-xs text-center">
                    {semtFilter === 'all'
                      ? `${CITIES[selectedCity]?.label || selectedCity} için tesis bulunamadı.`
                      : `"${semtFilter}" semtinde tesis yok.`}
                  </p>
                </div>
              ) : filteredTesisler.map(tesis => (
                <button
                  key={`card_tesisler_${tesis.id}`}
                  type="button"
                  onClick={() => handleCardClick(tesis, 'tesisler')}
                  className="w-full text-left p-3 rounded-xl border border-gray-200 hover:border-green-400 hover:bg-green-50/40 transition-all group active:scale-[0.98] shadow-sm"
                >
                  <div className="flex items-start gap-2.5">
                    <div className="w-8 h-8 rounded-lg bg-green-100 flex items-center justify-center text-green-700 shrink-0 mt-0.5 group-hover:bg-green-200 transition-colors text-sm">
                      ♻️
                    </div>
                    <div className="min-w-0 flex-1">
                      <p className="font-bold text-xs text-dark truncate">{tesis.tesis_adi}</p>
                      <p className="text-[11px] text-gray-500 truncate mt-0.5">
                        📍 {tesis.semt} / {tesis.city}
                      </p>
                    </div>
                    <MapPin className="w-3.5 h-3.5 text-green-400 shrink-0 opacity-0 group-hover:opacity-100 transition-opacity" />
                  </div>
                </button>
              ))
            )}
          </div>

          {/* Alt bilgi */}
          <div className="border-t border-gray-100 px-3 py-2 bg-gray-50/50">
            <p className="text-[10px] text-gray-400 text-center">
              {hasDbDepolar || hasDbTesisler
                ? '✅ Supabase veritabanından yüklendi'
                : '📋 Statik örnek veriler gösteriliyor'}
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
