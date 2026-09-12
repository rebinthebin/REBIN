import { useState, useRef, useEffect, useCallback } from 'react'
import { MapContainer, TileLayer, Marker, Popup, Polyline, useMap } from 'react-leaflet'
import L from 'leaflet'
import {
  Play,
  Square,
  RotateCcw,
  Navigation,
  Truck,
  AlertCircle,
  Shuffle,
  Filter,
  CheckCircle2,
  Sparkles,
  Check,
  Zap,
  Trash2,
  CheckSquare,
  Square as SquareIcon,
  ChevronDown,
  ChevronUp,
  ArrowRight,
  Factory,
  Building2,
  Cpu,
  ShieldCheck,
  Repeat,
  Layers,
} from 'lucide-react'
import { formatDistance, formatDuration } from '../services/osrm'
import {
  calcOccupancy,
  toPercent,
  CITIES,
  DEPOTS,
  FACILITIES,
  getBinCity,
} from '../utils/binUtils'
import LoadingSpinner from '../components/LoadingSpinner'
import CitySelector from '../components/CitySelector'
import { useSimulation } from '../context/SimulationContext'

// ─────────────────────────────────────────────────────────────────────────────
// Özel Marker İkonları & Efektleri
// ─────────────────────────────────────────────────────────────────────────────
function createBinIcon(type, occupancy, isCollected, isSelected = false, depotColor = '#2563EB') {
  const color = type === 'private' ? '#38A169' : '#2196F3'
  let fill = occupancy >= 0.85 ? '#EF5350' : occupancy >= 0.65 ? '#FFCA28' : color
  if (isCollected || occupancy === 0) {
    fill = '#10B981'
  }

  const textContent = isCollected || occupancy === 0 ? '✓' : `${Math.round(occupancy * 100)}%`

  const haloSvg = isSelected
    ? `<circle cx="16" cy="16" r="15" fill="${depotColor}" opacity="0.3"/>
       <circle cx="16" cy="16" r="13" fill="none" stroke="${depotColor}" stroke-width="2.5" stroke-dasharray="3,2"/>`
    : ''

  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="38" height="48" viewBox="0 0 38 48" style="overflow:visible;">
      <g transform="translate(3, 3)">
        ${haloSvg}
        <path d="M16 0 C7.16 0 0 7.16 0 16 C0 28 16 42 16 42 C16 42 32 28 32 16 C32 7.16 24.84 0 16 0Z" fill="${fill}" stroke="${isSelected ? depotColor : 'white'}" stroke-width="${isSelected ? '3' : '2'}"/>
        <circle cx="16" cy="16" r="8" fill="white" opacity="0.95"/>
        <text x="16" y="20" text-anchor="middle" font-size="${isCollected || occupancy === 0 ? '11' : '9'}" font-weight="bold" fill="${fill}">${textContent}</text>
      </g>
    </svg>
  `
  return L.divIcon({
    html: svg,
    className: isSelected ? 'selected-bin-marker' : '',
    iconSize: [38, 48],
    iconAnchor: [19, 45],
    popupAnchor: [0, -44],
  })
}

const depotTruckIcon = (depot) => {
  const emoji = depot?.truckEmoji || '🚚'
  const color = '#22C55E' // Açık yeşil rota uyumlu
  return L.divIcon({
    html: `
      <div style="display:flex;flex-direction:column;align-items:center;transform:translate(-50%, -50%);">
        <div style="font-size:28px;filter:drop-shadow(0 3px 6px rgba(0,0,0,0.4));">${emoji}</div>
        <div style="background:${color};color:white;font-size:9px;font-weight:bold;padding:1px 5px;border-radius:6px;border:1.5px solid white;box-shadow:0 2px 4px rgba(0,0,0,0.25);white-space:nowrap;">
          ${depot?.shortName || 'Araç'}
        </div>
      </div>
    `,
    className: '',
    iconSize: [0, 0],
    iconAnchor: [0, 0],
  })
}

// Mavi Depo İkonu (DB'den gelen depolar için - HaritaPage ile birebir uyumlu)
function createDepotIcon(name, color = '#1D4ED8', isSelected = false) {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="48" viewBox="0 0 40 48">
      <rect x="2" y="14" width="36" height="28" rx="5" fill="${color}" stroke="white" stroke-width="2"/>
      <polygon points="20,2 38,14 2,14" fill="${color}" stroke="white" stroke-width="2" stroke-linejoin="round"/>
      <rect x="14" y="26" width="12" height="16" rx="2" fill="white" opacity="0.9"/>
      <rect x="16" y="20" width="8" height="8" rx="1.5" fill="white" opacity="0.7"/>
    </svg>
  `
  return L.divIcon({
    html: `<div style="display:flex;flex-direction:column;align-items:center;gap:2px;transform:${isSelected ? 'scale(1.15)' : 'scale(1)'};transition:transform 0.2s;">
      ${svg}
      <div style="background:${color};color:white;border-radius:6px;padding:2px 6px;font-size:10px;font-weight:700;border:${isSelected ? '2px solid #FCD34D' : '1.5px solid white'};box-shadow:0 2px 6px rgba(0,0,0,0.25);white-space:nowrap;max-width:120px;overflow:hidden;text-overflow:ellipsis;">${name}</div>
    </div>`,
    className: '',
    iconSize: [40, 72],
    iconAnchor: [20, 72],
    popupAnchor: [0, -74],
  })
}

// Yeşil Tesis İkonu (DB'den gelen tesisler için - HaritaPage ile birebir uyumlu)
function createTesisIcon(name, color = '#15803D', isSelected = false) {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="40" height="48" viewBox="0 0 40 48">
      <circle cx="20" cy="22" r="18" fill="${color}" stroke="white" stroke-width="2"/>
      <text x="20" y="28" text-anchor="middle" font-size="20">♻️</text>
    </svg>
  `
  return L.divIcon({
    html: `<div style="display:flex;flex-direction:column;align-items:center;gap:2px;transform:${isSelected ? 'scale(1.15)' : 'scale(1)'};transition:transform 0.2s;">
      ${svg}
      <div style="background:${color};color:white;border-radius:6px;padding:2px 6px;font-size:10px;font-weight:700;border:${isSelected ? '2px solid #FCD34D' : '1.5px solid white'};box-shadow:0 2px 6px rgba(0,0,0,0.25);white-space:nowrap;max-width:120px;overflow:hidden;text-overflow:ellipsis;">${name}</div>
    </div>`,
    className: '',
    iconSize: [40, 72],
    iconAnchor: [20, 72],
    popupAnchor: [0, -74],
  })
}

// Statik fallback ikonları (Depolar)
const staticDepotIcon = (depotKey, depot, isSelected = false) => L.divIcon({
  html: `
    <div style="background:${depot?.color || '#2563EB'};color:white;border-radius:8px;padding:4px 8px;font-size:11px;font-weight:700;border:${isSelected ? '2.5px solid #FCD34D' : '2px solid white'};box-shadow:0 2px 8px rgba(0,0,0,0.3);white-space:nowrap;display:flex;align-items:center;gap:4px;transform:${isSelected ? 'scale(1.1)' : 'scale(1)'};transition:transform 0.2s;">
      <span>🏠</span>
      <span>${depot?.shortName || depotKey}</span>
    </div>
  `,
  className: '',
  iconSize: [null, null],
  iconAnchor: [30, 15],
})

// Statik fallback ikonları (Tesisler)
const staticFacilityIcon = (facility, isSelected = false) => L.divIcon({
  html: `
    <div style="background:${facility.color || '#7C3AED'};color:white;border-radius:10px;padding:4px 8px;font-size:11px;font-weight:700;border:${isSelected ? '2.5px solid #FCD34D' : '2px solid white'};box-shadow:0 2px 8px rgba(0,0,0,0.35);white-space:nowrap;display:flex;align-items:center;gap:4px;transform:${isSelected ? 'scale(1.1)' : 'scale(1)'};transition:transform 0.2s;">
      <span>🏭</span>
      <span>${facility.shortName || facility.name}</span>
    </div>
  `,
  className: '',
  iconSize: [null, null],
  iconAnchor: [40, 15],
})

function createWaypointIcon(occupancy, stopNumber, isCollected, depotColor = '#2563EB') {
  const pct = Math.round(occupancy * 100)
  const bg = isCollected ? '#10B981' : '#22C55E' // Açık yeşil rota uyumu
  const shadow = isCollected ? 'rgba(16,185,129,0.5)' : 'rgba(34,197,94,0.4)'

  return L.divIcon({
    html: `
      <div style="background:${bg};color:white;border-radius:50%;width:34px;height:34px;display:flex;flex-direction:column;align-items:center;justify-content:center;border:2px solid white;box-shadow:0 2px 8px ${shadow};font-size:9px;font-weight:800;line-height:1;transition:all 0.3s ease;">
        <span>${stopNumber ? '#' + stopNumber : ''}</span>
        <span style="font-size:10px;">${isCollected ? '✓' : pct + '%'}</span>
      </div>
    `,
    className: '',
    iconSize: [34, 34],
    iconAnchor: [17, 17],
  })
}

// Harita kontrolcüsü ve Görünür Alan (Bounds) dinleyicisi
function MapController({ city, onMapInstance }) {
  const map = useMap()
  const prevCity = useRef(null)

  useEffect(() => {
    if (onMapInstance) {
      onMapInstance(map)
    }
  }, [map, onMapInstance])

  useEffect(() => {
    if (city !== prevCity.current) {
      prevCity.current = city
      const cfg = CITIES[city] || CITIES.istanbul
      map.setView(cfg.center, 12, { animate: true, duration: 1 })
    }
  }, [city, map])

  return null
}

export default function YonetimPage() {
  const {
    bins,
    loadingBins: loading,
    binsError: error,
    addRandomBins,
    clearSimulationBins,
    selectedCity,
    setSelectedCity,
    selectedDepot,
    setSelectedDepot,
    selectedFacilityId,
    selectedFacility,
    setSelectedFacility,
    routes,
    currentRoute,
    calculateRoute,
    resetRoute,
    togglePlay,
    startAllFleets,
    allDepolar = [],
    allTesisler = [],
    dbDepolar = [],
    dbTesisler = [],
    dbLoading,
  } = useSimulation()

  // Harita örneği referansı
  const mapInstanceRef = useRef(null)
  const handleMapInstance = useCallback((map) => {
    mapInstanceRef.current = map
  }, [])

  // Ekstra Yerel Filtreler & Dropdown Durumları
  const [selectedSemt, setSelectedSemt] = useState('all')
  const [showSemtFilter, setShowSemtFilter] = useState(false)
  const [showDepotDropdown, setShowDepotDropdown] = useState(false)
  const [showFacilityDropdown, setShowFacilityDropdown] = useState(false)
  const [addingBins, setAddingBins] = useState(false)
  const [recentAddedCount, setRecentAddedCount] = useState(0)

  // Sağ alt filo takip widget'ı küçültme/büyütme durumu
  const [isFleetWidgetMinimized, setIsFleetWidgetMinimized] = useState(false)

  const depotDropdownRef = useRef(null)
  const facilityDropdownRef = useRef(null)

  // Dışarı tıklandığında açılır menüleri kapat
  useEffect(() => {
    const handleClickOutside = (e) => {
      if (depotDropdownRef.current && !depotDropdownRef.current.contains(e.target)) {
        setShowDepotDropdown(false)
      }
      if (facilityDropdownRef.current && !facilityDropdownRef.current.contains(e.target)) {
        setShowFacilityDropdown(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Depo bazlı seçilen kutu ID'leri
  const [selectedBinIds, setSelectedBinIds] = useState([])
  const hasUserCustomizedSelection = useRef(false)

  // Seçili şehre ait depoları ve tesisleri filtrele (DB-first, fallback: statik)
  const availableDepots = dbDepolar.length > 0
    ? dbDepolar.map(d => [
        String(d.id),
        {
          lat: d.latitude,
          lng: d.longitude,
          name: d.depo_adi,
          shortName: d.semt || d.depo_adi,
          city: d.city,
          color: '#2563EB',
          truckEmoji: '🚚',
        },
      ])
    : Object.entries(DEPOTS).filter(([, depot]) => depot.city === selectedCity)

  const availableFacilities = dbTesisler.length > 0
    ? dbTesisler.map(t => ({
        id: String(t.id),
        lat: t.latitude,
        lng: t.longitude,
        name: t.tesis_adi,
        shortName: t.semt || t.tesis_adi,
        region: t.semt,
        city: t.city,
        color: '#16A34A',
      }))
    : FACILITIES.filter(f => f.city === selectedCity)

  // Seçili şehirdeki kutular
  const cityBins = bins.filter(b => getBinCity(b) === selectedCity)

  // Mevcut semt seçenekleri
  const semtOptions = Array.from(
    new Set(cityBins.map(b => b.semt).filter(Boolean))
  ).sort()

  // Rota içindeki toplanan ID'ler
  const collectedIdSet = new Set(currentRoute?.collectedBinIds || [])
  const waypointIdSet = new Set((currentRoute?.waypoints || []).map(w => w.bin_id))

  // ───── DİĞER AKTİF/GÖREVLENDİRİLMİŞ DEPOLARA ATANMIŞ KUTULARI TESPİT ET ─────
  const lockedByOtherDepotIds = new Set()
  Object.entries(routes).forEach(([depotKey, route]) => {
    if (depotKey !== selectedDepot && route?.routeCoords && !route.completed) {
      route.waypoints.forEach(wp => {
        if (!route.collectedBinIds.includes(wp.bin_id)) {
          lockedByOtherDepotIds.add(wp.bin_id)
        }
      })
    }
  })

  // Boşaltım gerekli uygun kutular (Doluluğu >= %75 olan VE başka depoya atanmamış olanlar)
  const pendingEligibleBins = cityBins.filter(b => {
    const occ = calcOccupancy(b)
    const occOk = occ >= 0.75 && typeof b.latitude === 'number' && typeof b.longitude === 'number'
    const semtOk = selectedSemt === 'all' || b.semt === selectedSemt
    const notLocked = !lockedByOtherDepotIds.has(b.bin_id)
    return occOk && semtOk && notLocked
  })

  // Depo değiştiğinde veya yeni kutular geldiğinde otomatik seçim
  useEffect(() => {
    if (!hasUserCustomizedSelection.current) {
      const eligibleIds = pendingEligibleBins.map(b => b.bin_id)
      setSelectedBinIds(eligibleIds)
    }
  }, [selectedDepot, selectedCity, pendingEligibleBins.length])

  // Şehir değiştiğinde seçim özelleştirme kilidini sıfırla
  useEffect(() => {
    hasUserCustomizedSelection.current = false
    setSelectedSemt('all')
  }, [selectedCity])

  // Eğer bu depo için bir rota oluşturulmuşsa durakları göster
  const isRouteCreated = Boolean(currentRoute?.routeCoords && currentRoute.routeCoords.length > 0)

  // Listelenecek kutular
  let displayBins = []
  if (isRouteCreated && currentRoute.waypoints.length > 0) {
    displayBins = currentRoute.waypoints.map(wp => {
      const liveBin = bins.find(b => b.bin_id === wp.bin_id) || wp
      return liveBin
    })
  } else {
    displayBins = pendingEligibleBins
  }

  // Kutu seçimini aç/kapat (Checkbox)
  const toggleBinSelection = (binId) => {
    if (lockedByOtherDepotIds.has(binId)) return
    hasUserCustomizedSelection.current = true
    setSelectedBinIds(prev => {
      if (prev.includes(binId)) {
        return prev.filter(id => id !== binId)
      } else {
        return [...prev, binId]
      }
    })
  }

  // "Hepsini Seç" / "Tümünü Kaldır" işlemi
  const allCurrentEligibleIds = pendingEligibleBins.map(b => b.bin_id)
  const isAllSelected = allCurrentEligibleIds.length > 0 && allCurrentEligibleIds.every(id => selectedBinIds.includes(id))

  const handleToggleSelectAll = () => {
    hasUserCustomizedSelection.current = true
    if (isAllSelected) {
      const currentSet = new Set(allCurrentEligibleIds)
      setSelectedBinIds(prev => prev.filter(id => !currentSet.has(id)))
    } else {
      setSelectedBinIds(prev => Array.from(new Set([...prev, ...allCurrentEligibleIds])))
    }
  }

  // Rastgele 5 kutu ekleme tetikleyicisi
  const handleAddRandomBins = async () => {
    if (addingBins) return
    try {
      setAddingBins(true)
      let bounds = null
      if (mapInstanceRef.current && typeof mapInstanceRef.current.getBounds === 'function') {
        bounds = mapInstanceRef.current.getBounds()
      }
      const added = await addRandomBins(selectedCity, bounds)
      setRecentAddedCount(added.length)
      setTimeout(() => setRecentAddedCount(0), 4000)
    } finally {
      setAddingBins(false)
    }
  }

  // Simülasyonu ve tüm örnek kutuları sıfırla
  const handleResetSimulation = () => {
    if (window.confirm('Tüm örnek simülasyon kutuları silinecek ve filo rotaları sıfırlanacak. Devam etmek istiyor musunuz?')) {
      clearSimulationBins()
      setSelectedBinIds([])
      hasUserCustomizedSelection.current = false
    }
  }

  // Seçili rota hesapla
  const handleCalculateRoute = () => {
    const chosenIds = displayBins.filter(b => selectedBinIds.includes(b.bin_id) && !lockedByOtherDepotIds.has(b.bin_id)).map(b => b.bin_id)
    calculateRoute(selectedDepot, chosenIds.length > 0 ? chosenIds : selectedBinIds, selectedFacilityId)
  }

  const remainingDistance = currentRoute?.routeInfo ? currentRoute.routeInfo.distance * (1 - currentRoute.progress) : 0
  const remainingDuration = currentRoute?.routeInfo ? currentRoute.routeInfo.duration * (1 - currentRoute.progress) : 0

  // Temizlenen kutu sayısı
  const cleanedCount = displayBins.filter(b => collectedIdSet.has(b.bin_id) || calcOccupancy(b) === 0).length

  // Aktif çalışan / rotası oluşturulmuş tüm araçlar (Depo bazlı)
  const activeRoutesList = Object.entries(routes).filter(
    ([_, r]) => r && r.routeCoords && r.routeCoords.length > 0
  )

  const readyRoutesCount = activeRoutesList.filter(([_, r]) => !r.isPlaying && !r.completed).length
  const currentDepotConfig = availableDepots.find(([k]) => k === String(selectedDepot))?.[1] ||
    DEPOTS[selectedDepot] ||
    Object.values(DEPOTS).find(d => d.city === selectedCity) ||
    DEPOTS.A

  if (loading) {
    return (
      <div className="max-w-7xl mx-auto px-4 py-8">
        <LoadingSpinner text="Yönetim paneli yükleniyor..." />
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <AlertCircle className="w-12 h-12 text-red-400" />
        <p className="text-gray-600">Veriler yüklenemedi: {error}</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col lg:flex-row h-[calc(100vh-64px)] overflow-hidden">
      {/* ───── Sol Panel (Yeniden Yapılandırılmış, Ferah Rota & Görev Yönetimi) ───── */}
      <div className="w-full lg:w-[440px] min-w-[340px] bg-white border-r border-gray-200 flex flex-col h-full z-10 shadow-sm">
        
        {/* Panel Üst Başlığı & Hızlı Aksiyonlar */}
        <div className="p-4 border-b border-gray-100 flex items-center justify-between gap-2 bg-gradient-to-r from-white via-white to-gray-50/60">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center text-primary shrink-0 shadow-xs">
              <Truck className="w-5 h-5" />
            </div>
            <div>
              <h2 className="font-extrabold text-dark text-base tracking-tight leading-tight">Filo & Rota Yönetimi</h2>
              <p className="text-xs text-gray-500 flex items-center gap-1.5 mt-0.5">
                <span>Akıllı Toplama</span>
                <span className="w-1 h-1 rounded-full bg-gray-300"></span>
                <span className="text-primary font-medium">TSP Optimizasyonu</span>
              </p>
            </div>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <button
              onClick={handleAddRandomBins}
              disabled={addingBins}
              className="flex items-center gap-1.5 bg-emerald-50 hover:bg-emerald-100 text-emerald-700 text-xs font-bold px-3 py-2 rounded-xl border border-emerald-200 transition-all shadow-xs active:scale-95 disabled:opacity-50"
              title="Haritada görüntülediğiniz alanın içerisine rastgele 5 kutu ekler"
            >
              <Shuffle className={`w-3.5 h-3.5 ${addingBins ? 'animate-spin' : ''}`} />
              {addingBins ? 'Ekleniyor...' : '+5 Kutu'}
            </button>

            <button
              onClick={handleResetSimulation}
              className="p-2 rounded-xl border border-gray-200 bg-gray-50 hover:bg-red-50 text-gray-500 hover:text-red-600 hover:border-red-200 transition-colors shadow-xs active:scale-95"
              title="Tüm simülasyon kutularını temizle ve sistemi sıfırla"
            >
              <Trash2 className="w-4 h-4" />
            </button>
          </div>
        </div>

        {recentAddedCount > 0 && (
          <div className="bg-emerald-50 px-4 py-2.5 text-xs text-emerald-800 flex items-center gap-2 border-b border-emerald-100 animate-fadeIn">
            <Sparkles className="w-4 h-4 text-emerald-600 shrink-0" />
            <span>5 yeni kutu harita görünüm alanına eklendi! (%75+ dolu olanlar listelendi)</span>
          </div>
        )}

        {/* ───── Ferahlatılmış Rota Güzergahı (Şehir, Depo ve Tesis Seçimi) ───── */}
        <div className="p-4 border-b border-gray-100 space-y-3.5 bg-slate-50/50">
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-[11px] font-bold text-gray-500 uppercase tracking-wider flex items-center gap-1.5">
                <Building2 className="w-3.5 h-3.5 text-gray-400" />
                Yönetilen Bölge / Şehir
              </label>
              <span className="text-[11px] text-gray-500 font-semibold bg-white px-2 py-0.5 rounded-md border border-gray-200 shadow-2xs">
                {pendingEligibleBins.length} Boşaltılacak Kutu
              </span>
            </div>
            <CitySelector
              selectedCity={selectedCity}
              onSelectCity={setSelectedCity}
              className="w-full shadow-xs"
            />
          </div>

          {/* ───── [Depo Seç ▾] ➔ [Tesis Seç ▾] Arayüzü ───── */}
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <label className="text-[11px] font-bold text-gray-500 uppercase tracking-wider flex items-center gap-1.5">
                <Navigation className="w-3.5 h-3.5 text-gray-400" />
                Rota Güzergahı (Başlangıç → Varış)
              </label>
              <span className="text-[10px] text-blue-600 font-medium">
                {availableDepots.length} Depo & {availableFacilities.length} Tesis
              </span>
            </div>

            <div className="flex items-center gap-2">
              {/* Sol: Depo Seç Butonu / Dropdown */}
              <div className="relative flex-1" ref={depotDropdownRef}>
                <button
                  type="button"
                  onClick={() => {
                    setShowDepotDropdown(v => !v)
                    setShowFacilityDropdown(false)
                  }}
                  className="w-full flex items-center justify-between gap-2 p-2.5 rounded-xl border-2 border-blue-200/90 bg-white hover:border-blue-400 text-left shadow-xs transition-all cursor-pointer"
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-lg shrink-0">🏢</span>
                    <div className="min-w-0">
                      <p className="text-[10px] text-blue-600 font-bold uppercase tracking-wider leading-none">Depo (Başlangıç)</p>
                      <p className="text-xs font-extrabold text-dark truncate mt-0.5">{currentDepotConfig.shortName}</p>
                    </div>
                  </div>
                  <ChevronDown className={`w-4 h-4 text-gray-400 shrink-0 transition-transform ${showDepotDropdown ? 'rotate-180' : ''}`} />
                </button>

                {/* Depo Açılır Listesi */}
                {showDepotDropdown && (
                  <div className="absolute left-0 top-full mt-1.5 w-64 bg-white border border-gray-100 rounded-2xl shadow-xl py-1.5 z-30 animate-fadeIn">
                    <div className="px-3 py-1.5 text-[10px] font-bold text-gray-400 uppercase tracking-wider border-b border-gray-50 flex items-center justify-between">
                      <span>Başlangıç Deposu Seçin</span>
                      <span className="text-blue-600 font-bold">Mavi Marker</span>
                    </div>
                    {availableDepots.map(([key, depot]) => {
                      const isSelected = selectedDepot === key
                      const depotRoute = routes[key]
                      const isMoving = depotRoute?.isPlaying
                      const hasRoute = Boolean(depotRoute?.routeCoords && depotRoute.routeCoords.length > 0)

                      return (
                        <button
                          key={key}
                          type="button"
                          onClick={() => {
                            setSelectedDepot(key)
                            setShowDepotDropdown(false)
                          }}
                          className={`w-full text-left px-3 py-2.5 flex items-center justify-between hover:bg-blue-50/50 transition-colors ${
                            isSelected ? 'bg-blue-50/80 text-primary font-bold' : 'text-gray-700'
                          }`}
                        >
                          <div className="flex items-center gap-2.5 min-w-0">
                            <span className="text-base">🏢</span>
                            <div className="min-w-0">
                              <p className="text-xs font-semibold truncate">{depot.name}</p>
                              <p className="text-[10px] text-gray-400">
                                {isMoving ? '🟢 Araç Yolda' : hasRoute ? '🟡 Rota Hazır' : '⚪ Bekliyor'}
                              </p>
                            </div>
                          </div>
                          {isSelected && <CheckCircle2 className="w-4 h-4 text-primary shrink-0" />}
                        </button>
                      )
                    })}
                  </div>
                )}
              </div>

              {/* Ortadaki Yön Oku */}
              <div className="p-1.5 rounded-full bg-gray-100 text-gray-400 shrink-0">
                <ArrowRight className="w-4 h-4" />
              </div>

              {/* Sağ: Varış Noktası (Tesis veya Döngüsel Depo) Seç Butonu / Dropdown */}
              <div className="relative flex-1" ref={facilityDropdownRef}>
                <button
                  type="button"
                  onClick={() => {
                    setShowFacilityDropdown(v => !v)
                    setShowDepotDropdown(false)
                  }}
                  className={`w-full flex items-center justify-between gap-2 p-2.5 rounded-xl border-2 text-left shadow-xs transition-all cursor-pointer ${
                    selectedFacilityId === 'depot_return'
                      ? 'border-blue-300 bg-blue-50/40 hover:border-blue-400'
                      : 'border-emerald-200/90 bg-white hover:border-emerald-400'
                  }`}
                >
                  <div className="flex items-center gap-2 min-w-0">
                    <span className="text-lg shrink-0">{selectedFacilityId === 'depot_return' ? '🔄' : '♻️'}</span>
                    <div className="min-w-0">
                      <p className="text-[10px] text-emerald-600 font-bold uppercase tracking-wider leading-none">
                        {selectedFacilityId === 'depot_return' ? 'Döngüsel' : 'Varış Tesisi'}
                      </p>
                      <p className={`text-xs font-extrabold truncate mt-0.5 ${
                        selectedFacilityId === 'depot_return' ? 'text-blue-900' : 'text-emerald-900'
                      }`}>
                        {selectedFacilityId === 'depot_return' ? `${currentDepotConfig.shortName} (Döngü)` : (selectedFacility?.shortName || 'Tesis')}
                      </p>
                    </div>
                  </div>
                  <ChevronDown className={`w-4 h-4 text-gray-400 shrink-0 transition-transform ${showFacilityDropdown ? 'rotate-180' : ''}`} />
                </button>

                {/* Varış Noktası Açılır Listesi (Döngüsel Depo + Tesisler) */}
                {showFacilityDropdown && (
                  <div className="absolute right-0 top-full mt-1.5 w-72 bg-white border border-gray-100 rounded-2xl shadow-xl py-1.5 z-30 animate-fadeIn">
                    <div className="px-3 py-1.5 text-[10px] font-bold text-gray-400 uppercase tracking-wider border-b border-gray-50">
                      Döngüsel Rota (Tam TSP)
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        setSelectedFacility('depot_return')
                        setShowFacilityDropdown(false)
                      }}
                      className={`w-full text-left px-3 py-2.5 flex items-center justify-between hover:bg-blue-50/60 transition-colors ${
                        selectedFacilityId === 'depot_return' ? 'bg-blue-50 text-primary font-bold' : 'text-gray-700'
                      }`}
                    >
                      <div className="flex items-center gap-2 min-w-0">
                        <span className="text-base">🔄</span>
                        <div className="min-w-0">
                          <p className="text-xs font-semibold truncate">{currentDepotConfig.name}</p>
                          <p className="text-[10px] text-blue-600 font-medium">Depo'ya Geri Dön (Kapalı TSP Çemberi)</p>
                        </div>
                      </div>
                      {selectedFacilityId === 'depot_return' && <CheckCircle2 className="w-4 h-4 text-primary shrink-0" />}
                    </button>

                    <div className="px-3 py-1.5 text-[10px] font-bold text-gray-400 uppercase tracking-wider border-b border-t border-gray-50 mt-1 flex items-center justify-between">
                      <span>Hedef Geri Dönüşüm Tesisi</span>
                      <span className="text-emerald-600 font-bold">Yeşil Marker</span>
                    </div>
                    {availableFacilities.map((fac) => {
                      const isSelected = selectedFacilityId === fac.id

                      return (
                        <button
                          key={fac.id}
                          type="button"
                          onClick={() => {
                            setSelectedFacility(fac.id)
                            setShowFacilityDropdown(false)
                          }}
                          className={`w-full text-left px-3 py-2.5 flex items-center justify-between hover:bg-emerald-50/50 transition-colors ${
                            isSelected ? 'bg-emerald-50 text-emerald-800 font-bold' : 'text-gray-700'
                          }`}
                        >
                          <div className="flex items-center gap-2 min-w-0">
                            <span className="text-base">♻️</span>
                            <div className="min-w-0">
                              <p className="text-xs font-semibold truncate">{fac.name}</p>
                              <p className="text-[10px] text-gray-400">{fac.region || fac.city}</p>
                            </div>
                          </div>
                          {isSelected && <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />}
                        </button>
                      )
                    })}
                  </div>
                )}
              </div>
            </div>

            <div className="text-[11px] text-gray-500 mt-2 flex items-center gap-1.5 px-1 truncate">
              <span className="font-semibold text-blue-700 flex items-center gap-1">
                <span>🏢</span>
                <span className="truncate">{currentDepotConfig.name}</span>
              </span>
              <span className="text-gray-400">→</span>
              {selectedFacilityId === 'depot_return' ? (
                <span className="text-blue-700 font-semibold flex items-center gap-1">
                  <span>🔄 Kapalı Çember TSP</span>
                </span>
              ) : (
                <span className="text-emerald-700 font-semibold flex items-center gap-1 truncate">
                  <span>♻️</span>
                  <span className="truncate">{selectedFacility?.name}</span>
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Semt Filtresi, "Hepsini Seç" ve Liste Başlığı */}
        <div className="px-4 py-3 border-b border-gray-100 flex items-center justify-between bg-white gap-2">
          <div className="flex items-center gap-2 min-w-0">
            <span className="text-xs font-extrabold text-dark uppercase tracking-wider truncate">
              {isRouteCreated ? 'Rota Durakları' : 'Boşaltım Gerekli Kutular'}
            </span>
            <span className={`text-xs font-bold px-2 py-0.5 rounded-full shrink-0 ${
              cleanedCount > 0 && cleanedCount === displayBins.length
                ? 'bg-emerald-100 text-emerald-700'
                : 'bg-blue-100 text-blue-700'
            }`}>
              {isRouteCreated
                ? `${cleanedCount}/${displayBins.length} Temizlendi`
                : `${displayBins.filter(b => selectedBinIds.includes(b.bin_id)).length}/${displayBins.length} Seçili`}
            </span>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            {/* "Hepsini Seç" Butonu */}
            {!isRouteCreated && displayBins.length > 0 && (
              <button
                onClick={handleToggleSelectAll}
                className={`px-2.5 py-1.5 rounded-xl text-xs font-semibold border flex items-center gap-1.5 transition-all active:scale-95 cursor-pointer ${
                  isAllSelected
                    ? 'bg-primary text-white border-primary shadow-xs'
                    : 'bg-white text-gray-600 border-gray-200 hover:bg-gray-50'
                }`}
                title={isAllSelected ? 'Tüm seçimleri kaldır' : 'Bölgedeki tüm kutuları seç'}
              >
                {isAllSelected ? <CheckSquare className="w-3.5 h-3.5" /> : <SquareIcon className="w-3.5 h-3.5" />}
                <span>{isAllSelected ? 'Tümünü Kaldır' : 'Hepsini Seç'}</span>
              </button>
            )}

            {/* Semt Filtresi */}
            {semtOptions.length > 0 && !isRouteCreated && (
              <div className="relative">
                <button
                  onClick={() => setShowSemtFilter(v => !v)}
                  className={`p-2 rounded-xl text-xs font-medium border flex items-center gap-1 transition-colors cursor-pointer ${
                    selectedSemt !== 'all'
                      ? 'bg-primary text-white border-primary shadow-xs'
                      : 'text-gray-500 border-gray-200 hover:bg-gray-50'
                  }`}
                  title="Semte göre filtrele"
                >
                  <Filter className="w-3.5 h-3.5" />
                </button>

                {showSemtFilter && (
                  <div className="absolute right-0 top-full mt-1 w-48 bg-white border border-gray-100 rounded-xl shadow-xl py-1.5 z-20 max-h-52 overflow-y-auto">
                    <button
                      onClick={() => { setSelectedSemt('all'); setShowSemtFilter(false) }}
                      className={`w-full text-left px-3 py-2 text-xs transition-colors ${
                        selectedSemt === 'all' ? 'bg-primary/10 text-primary font-bold' : 'text-gray-700 hover:bg-gray-50'
                      }`}
                    >
                      Tüm Semtler
                    </button>
                    {semtOptions.map(s => (
                      <button
                        key={s}
                        onClick={() => { setSelectedSemt(s); setShowSemtFilter(false) }}
                        className={`w-full text-left px-3 py-2 text-xs transition-colors ${
                          selectedSemt === s ? 'bg-primary/10 text-primary font-bold' : 'text-gray-700 hover:bg-gray-50'
                        }`}
                      >
                        📍 {s}
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* ───── Kutu Listesi (Daha Ferah, Uzun ve Net Scroll Alanı) ───── */}
        <div className="flex-1 overflow-y-auto p-3.5 space-y-2.5">
          {displayBins.length === 0 ? (
            <div className="text-center py-16 px-4">
              <div className="w-14 h-14 rounded-2xl bg-gray-100 flex items-center justify-center mx-auto text-gray-400 mb-3 shadow-2xs">
                <Truck className="w-7 h-7" />
              </div>
              <p className="text-gray-700 text-sm font-bold">Boşaltım Gerekli Kutu Yok</p>
              <p className="text-gray-400 text-xs mt-1 max-w-xs mx-auto">
                {selectedCity === 'ankara' ? 'Ankara' : 'İstanbul'} için %75 üzerinde boşta bekleyen kutu bulunmuyor.
              </p>
              <button
                onClick={handleAddRandomBins}
                disabled={addingBins}
                className="mt-4 inline-flex items-center gap-1.5 text-xs font-semibold text-primary bg-primary/10 hover:bg-primary/20 px-4 py-2 rounded-xl transition-colors cursor-pointer"
              >
                <Shuffle className="w-3.5 h-3.5" />
                Haritaya 5 Kutu Ekle
              </button>
            </div>
          ) : (
            displayBins.map((bin, index) => {
              const occ = calcOccupancy(bin)
              const isCollected = collectedIdSet.has(bin.bin_id) || occ === 0
              const isInRoute = waypointIdSet.has(bin.bin_id)
              const isSelected = selectedBinIds.includes(bin.bin_id)
              const isLocked = lockedByOtherDepotIds.has(bin.bin_id)
              const stopNumber = currentRoute?.waypoints ? currentRoute.waypoints.findIndex(w => w.bin_id === bin.bin_id) + 1 : 0

              return (
                <div
                  key={bin.bin_id ?? index}
                  onClick={() => {
                    if (!isRouteCreated && !isLocked) toggleBinSelection(bin.bin_id)
                  }}
                  className={`p-3 rounded-xl border transition-all duration-200 ${
                    isCollected
                      ? 'bg-emerald-50/90 border-emerald-300 text-emerald-950 shadow-xs'
                      : isInRoute
                      ? 'bg-emerald-50/60 border-emerald-300 shadow-xs'
                      : isSelected
                      ? 'bg-white border-primary/50 shadow-sm ring-1 ring-primary/20 cursor-pointer'
                      : isLocked
                      ? 'bg-gray-100 border-gray-200 opacity-50 cursor-not-allowed'
                      : 'bg-gray-50/70 border-gray-200 opacity-60 hover:opacity-100 cursor-pointer'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2.5">
                    {/* Tiklenebilir Seçim Kutusu / Durak Numarası */}
                    <div className="flex items-center gap-2.5 flex-1 min-w-0">
                      {!isRouteCreated ? (
                        <div
                          className={`w-5 h-5 rounded-lg border flex items-center justify-center transition-colors shrink-0 ${
                            isSelected
                              ? 'bg-primary border-primary text-white shadow-2xs'
                              : isLocked
                              ? 'bg-gray-200 border-gray-300 text-gray-400'
                              : 'bg-white border-gray-300'
                          }`}
                        >
                          {isSelected && <Check className="w-3.5 h-3.5 stroke-[3]" />}
                        </div>
                      ) : isCollected ? (
                        <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
                      ) : stopNumber > 0 ? (
                        <span
                          className="w-5 h-5 rounded-full text-white text-[10px] font-bold flex items-center justify-center shrink-0 shadow-2xs bg-emerald-600"
                        >
                          {stopNumber}
                        </span>
                      ) : null}

                      <div className="flex-1 min-w-0">
                        <div className="flex items-center gap-1.5">
                          <span className={`font-semibold text-xs truncate ${isCollected ? 'text-emerald-950 font-bold' : isSelected ? 'text-dark font-bold' : 'text-gray-600'}`}>
                            {bin.name || bin.bin_id}
                          </span>
                        </div>

                        <p className={`text-[11px] font-mono mt-0.5 truncate ${isCollected ? 'text-emerald-700' : 'text-gray-400'}`}>
                          {bin.bin_id}
                        </p>

                        {bin.semt && (
                          <p className={`text-[11px] mt-0.5 flex items-center gap-1 ${isCollected ? 'text-emerald-700 font-medium' : 'text-gray-500'}`}>
                            <span>📍 {bin.semt}</span>
                            {isCollected && <span>· Boşaltıldı</span>}
                          </p>
                        )}
                      </div>
                    </div>

                    {/* Doluluk / Tamamlandı Rozeti */}
                    <div className="shrink-0 text-right">
                      {isCollected ? (
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500 text-white inline-flex items-center gap-0.5 shadow-2xs">
                          <Check className="w-3 h-3 stroke-[3]" /> %0 Temiz
                        </span>
                      ) : (
                        <span
                          className="text-xs font-bold px-2.5 py-0.5 rounded-full text-white inline-block transition-colors shadow-2xs"
                          style={{
                            background: occ >= 0.85 ? '#EF5350' : '#FFCA28',
                            color: occ >= 0.85 ? 'white' : '#1A202C',
                          }}
                        >
                          {toPercent(occ)}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
              )
            })
          )}
        </div>

        {/* Aksiyon & Kontrol Paneli (Alt Kısım) */}
        <div className="p-4 border-t border-gray-100 bg-white space-y-2.5">
          {currentRoute?.routeError && (
            <div className="bg-red-50 border border-red-200 rounded-xl p-3 text-xs text-red-600 flex items-start gap-2">
              <AlertCircle className="w-4 h-4 text-red-500 mt-0.5 shrink-0" />
              <span>{currentRoute.routeError}</span>
            </div>
          )}

          {/* Rota Özeti Bilgisi & Optimizasyon Metrikleri */}
          {currentRoute?.routeInfo && !currentRoute.calculating && (
            <div className="bg-emerald-50/40 border border-emerald-200/70 rounded-xl p-3 space-y-2">
              <div className="flex justify-between items-center text-xs">
                <span className="text-gray-600 flex items-center gap-1.5 font-medium">
                  <span>🚚</span>
                  <span>{currentRoute.depotName || selectedDepot} Rotası:</span>
                </span>
                <span className="font-bold text-dark">
                  {formatDistance(currentRoute.routeInfo.distance)} · {formatDuration(currentRoute.routeInfo.duration)}
                </span>
              </div>

              {/* Optimizasyon Motoru ve 2-Opt Rozetleri */}
              {currentRoute.routeInfo.optimization && (
                <div className="bg-white/90 border border-emerald-200/80 rounded-xl p-2.5 space-y-1.5 shadow-2xs">
                  <div className="flex items-center justify-between gap-1">
                    <span className="text-[10px] font-bold text-emerald-900 flex items-center gap-1 truncate">
                      <Cpu className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                      <span className="truncate">{currentRoute.routeInfo.optimization.algorithm}</span>
                    </span>
                    <span className="text-[9px] bg-emerald-100 text-emerald-800 font-mono font-bold px-1.5 py-0.5 rounded shrink-0">
                      {currentRoute.routeInfo.optimization.matrixSource}
                    </span>
                  </div>

                  <div className="flex items-center justify-between text-[10px] text-gray-600 pt-0.5 border-t border-gray-100">
                    <span className="flex items-center gap-1 text-emerald-700 font-semibold">
                      <ShieldCheck className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                      <span>2-Opt Çapraz Kesişim Engellendi</span>
                    </span>
                    <span className="font-mono text-[9px] text-gray-500 bg-gray-50 px-1.5 py-0.5 rounded border border-gray-200">
                      {currentRoute.routeInfo.optimization.computationTimeMs} ms
                    </span>
                  </div>

                  {currentRoute.routeInfo.optimization.improvementPercent > 0 && (
                    <div className="text-[9.5px] text-emerald-900 bg-emerald-50 px-2 py-1 rounded-md flex items-center justify-between font-medium">
                      <span>Zig-Zag Önleme Tasarrufu:</span>
                      <span className="font-bold font-mono text-emerald-700">-%{currentRoute.routeInfo.optimization.improvementPercent} Sürüş Süresi</span>
                    </div>
                  )}
                </div>
              )}

              <div className="flex justify-between text-xs">
                <span className="text-gray-500">Varış Noktası:</span>
                <span className="font-bold text-emerald-700 flex items-center gap-1">
                  {currentRoute.isReturnToDepot ? (
                    <span className="text-blue-700 flex items-center gap-1">
                      <Repeat className="w-3 h-3" />
                      <span>{currentRoute.facilityShortName || `${currentDepotConfig.shortName} Depo`}</span>
                    </span>
                  ) : (
                    <span>♻️ {currentRoute.facilityShortName || selectedFacility?.shortName}</span>
                  )}
                </span>
              </div>

              <div className="flex justify-between text-xs">
                <span className="text-gray-500">Durum:</span>
                <span className="font-bold text-emerald-700">
                  {cleanedCount} / {currentRoute.routeInfo.stops} Kutu Boşaltıldı
                </span>
              </div>

              <div className="w-full bg-gray-200 rounded-full h-2 mt-1 overflow-hidden">
                <div
                  className="h-2 rounded-full transition-all duration-300"
                  style={{
                    width: `${currentRoute.progress * 100}%`,
                    backgroundColor: '#22C55E',
                  }}
                />
              </div>
            </div>
          )}

          {currentRoute?.completed && (
            <div className="bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs text-center rounded-xl p-2.5 font-bold flex items-center justify-center gap-1.5 shadow-2xs">
              <CheckCircle2 className="w-4 h-4 text-emerald-600" />
              {currentRoute.shortName} Aracı {currentRoute.facilityShortName || 'Hedefe'} Ulaştı!
            </div>
          )}

          {/* Rota Hesapla & Optimize Et Butonu */}
          <button
            onClick={handleCalculateRoute}
            disabled={currentRoute?.calculating || selectedBinIds.length === 0}
            className="w-full flex items-center justify-center gap-2 bg-primary text-white font-bold py-3 rounded-xl hover:bg-primary-dark transition-all shadow-sm active:scale-98 disabled:opacity-50 disabled:cursor-not-allowed text-sm cursor-pointer"
          >
            <Zap className="w-4 h-4" />
            {currentRoute?.calculating
              ? 'OSRM Table & TSP Optimize Ediliyor...'
              : `${currentDepotConfig.shortName} → ${
                  selectedFacilityId === 'depot_return' ? `${currentDepotConfig.shortName} (Döngü)` : (selectedFacility?.shortName || 'Tesis')
                } (${displayBins.filter(b => selectedBinIds.includes(b.bin_id)).length} Kutu) Rotayı Optimize Et`}
          </button>

          {/* Simülasyon Oynat / Durdur / Sıfırla */}
          {currentRoute?.routeCoords && !currentRoute.calculating && (
            <div className="grid grid-cols-2 gap-2 pt-0.5">
              <button
                onClick={() => togglePlay(selectedDepot)}
                disabled={currentRoute.completed}
                className={`flex items-center justify-center gap-2 font-bold py-2.5 rounded-xl transition-all text-xs sm:text-sm cursor-pointer ${
                  currentRoute.isPlaying
                    ? 'bg-amber-100 text-amber-800 hover:bg-amber-200 shadow-xs'
                    : 'bg-emerald-100 text-emerald-800 hover:bg-emerald-200 shadow-xs'
                } disabled:opacity-40`}
              >
                {currentRoute.isPlaying ? <Square className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                {currentRoute.isPlaying ? 'Durdur' : currentRoute.completed ? 'Tamamlandı' : 'Aracı Başlat'}
              </button>

              <button
                onClick={() => resetRoute(selectedDepot)}
                className="flex items-center justify-center gap-1.5 font-bold py-2.5 rounded-xl bg-gray-100 text-gray-700 hover:bg-gray-200 transition-colors text-xs sm:text-sm cursor-pointer shadow-2xs"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                Rotayı Sıfırla
              </button>
            </div>
          )}
        </div>
      </div>

      {/* ───── Sağ Alan: Canlı Çoklu Harita & Sağ Alt Filo Takip Paneli ───── */}
      <div className="flex-1 relative h-full">
        <MapContainer
          center={CITIES[selectedCity]?.center || CITIES.istanbul.center}
          zoom={12}
          style={{ height: '100%', width: '100%' }}
        >
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />

          {/* Harita Kontrolcüsü ve Bounds Dinleyicisi */}
          <MapController city={selectedCity} onMapInstance={handleMapInstance} />

          {/* ── 1. DEPO MARKERLARI (DB varsa DB depolar, yoksa statik depolar) ── */}
          {dbDepolar.length > 0 && dbDepolar.map(depo => {
            if (typeof depo.latitude !== 'number' || typeof depo.longitude !== 'number') return null
            const depotId = String(depo.id)
            const isCurrentDepot = String(selectedDepot) === depotId

            return (
              <Marker
                key={`db_depo_${depotId}`}
                position={[depo.latitude, depo.longitude]}
                icon={createDepotIcon(depo.depo_adi, isCurrentDepot ? '#1D4ED8' : '#2563EB', isCurrentDepot)}
                zIndexOffset={isCurrentDepot ? 900 : 500}
                eventHandlers={{
                  click: () => setSelectedDepot(depotId),
                }}
              >
                <Popup>
                  <div style={{ minWidth: 160, fontFamily: 'sans-serif' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                      <span style={{ fontSize: 18 }}>🏠</span>
                      <p style={{ fontWeight: 700, fontSize: 13, color: '#1D4ED8', margin: 0 }}>{depo.depo_adi}</p>
                    </div>
                    <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 4px' }}>
                      📍 {depo.semt} / {depo.city}
                    </p>
                    {isCurrentDepot ? (
                      <span style={{ fontSize: 10, background: '#EFF6FF', color: '#1D4ED8', padding: '2px 8px', borderRadius: 99, fontWeight: 700, display: 'inline-block' }}>
                        ✓ Aktif Başlangıç Deposu
                      </span>
                    ) : (
                      <button
                        onClick={() => setSelectedDepot(depotId)}
                        style={{ marginTop: 4, width: '100%', background: '#2563EB', color: 'white', fontSize: 11, fontWeight: 700, padding: '4px 8px', borderRadius: 6, border: 'none', cursor: 'pointer' }}
                      >
                        Bu Depoyu Başlangıç Yap →
                      </button>
                    )}
                  </div>
                </Popup>
              </Marker>
            )
          })}

          {dbDepolar.length === 0 && Object.entries(DEPOTS)
            .filter(([, d]) => d.city === selectedCity)
            .map(([key, depot]) => {
              const isCurrentDepot = selectedDepot === key
              return (
                <Marker
                  key={`static_depo_${key}`}
                  position={[depot.lat, depot.lng]}
                  icon={staticDepotIcon(key, depot, isCurrentDepot)}
                  zIndexOffset={isCurrentDepot ? 900 : 500}
                  eventHandlers={{
                    click: () => setSelectedDepot(key),
                  }}
                >
                  <Popup>
                    <div style={{ minWidth: 160, fontFamily: 'sans-serif' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                        <span style={{ fontSize: 18 }}>🏠</span>
                        <p style={{ fontWeight: 700, fontSize: 13, color: '#1D4ED8', margin: 0 }}>{depot.name}</p>
                      </div>
                      <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 4px' }}>
                        📍 {depot.shortName} / {depot.city === 'ankara' ? 'Ankara' : 'İstanbul'}
                      </p>
                      {isCurrentDepot ? (
                        <span style={{ fontSize: 10, background: '#EFF6FF', color: '#1D4ED8', padding: '2px 8px', borderRadius: 99, fontWeight: 700, display: 'inline-block' }}>
                          ✓ Aktif Başlangıç Deposu
                        </span>
                      ) : (
                        <button
                          onClick={() => setSelectedDepot(key)}
                          style={{ marginTop: 4, width: '100%', background: '#2563EB', color: 'white', fontSize: 11, fontWeight: 700, padding: '4px 8px', borderRadius: 6, border: 'none', cursor: 'pointer' }}
                        >
                          Bu Depoyu Başlangıç Yap →
                        </button>
                      )}
                    </div>
                  </Popup>
                </Marker>
              )
            })}

          {/* ── 2. TESİS MARKERLARI (DB varsa DB tesisler, yoksa statik tesisler) ── */}
          {dbTesisler.length > 0 && dbTesisler.map(tesis => {
            if (typeof tesis.latitude !== 'number' || typeof tesis.longitude !== 'number') return null
            const tesisId = String(tesis.id)
            const isSelected = selectedFacilityId === tesisId

            return (
              <Marker
                key={`db_tesis_${tesisId}`}
                position={[tesis.latitude, tesis.longitude]}
                icon={createTesisIcon(tesis.tesis_adi, isSelected ? '#15803D' : '#16A34A', isSelected)}
                zIndexOffset={isSelected ? 900 : 500}
                eventHandlers={{
                  click: () => setSelectedFacility(tesisId),
                }}
              >
                <Popup>
                  <div style={{ minWidth: 160, fontFamily: 'sans-serif' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                      <span style={{ fontSize: 18 }}>♻️</span>
                      <p style={{ fontWeight: 700, fontSize: 13, color: '#15803D', margin: 0 }}>{tesis.tesis_adi}</p>
                    </div>
                    <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 4px' }}>
                      📍 {tesis.semt} / {tesis.city}
                    </p>
                    {isSelected ? (
                      <span style={{ fontSize: 10, background: '#F0FDF4', color: '#15803D', padding: '2px 8px', borderRadius: 99, fontWeight: 700, display: 'inline-block' }}>
                        ✓ Aktif Varış Tesisi
                      </span>
                    ) : (
                      <button
                        onClick={() => setSelectedFacility(tesisId)}
                        style={{ marginTop: 4, width: '100%', background: '#16A34A', color: 'white', fontSize: 11, fontWeight: 700, padding: '4px 8px', borderRadius: 6, border: 'none', cursor: 'pointer' }}
                      >
                        Hedef Tesis Olarak Seç →
                      </button>
                    )}
                  </div>
                </Popup>
              </Marker>
            )
          })}

          {dbTesisler.length === 0 && FACILITIES
            .filter(f => f.city === selectedCity)
            .map(fac => {
              const isSelected = selectedFacilityId === fac.id
              return (
                <Marker
                  key={`static_fac_${fac.id}`}
                  position={[fac.lat, fac.lng]}
                  icon={staticFacilityIcon(fac, isSelected)}
                  zIndexOffset={isSelected ? 900 : 500}
                  eventHandlers={{
                    click: () => setSelectedFacility(fac.id),
                  }}
                >
                  <Popup>
                    <div style={{ minWidth: 160, fontFamily: 'sans-serif' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 4 }}>
                        <span style={{ fontSize: 18 }}>🏭</span>
                        <p style={{ fontWeight: 700, fontSize: 13, color: '#7C3AED', margin: 0 }}>{fac.name}</p>
                      </div>
                      <p style={{ fontSize: 11, color: '#6B7280', margin: '0 0 4px' }}>
                        📍 {fac.region || fac.city}
                      </p>
                      {isSelected ? (
                        <span style={{ fontSize: 10, background: '#F5F3FF', color: '#7C3AED', padding: '2px 8px', borderRadius: 99, fontWeight: 700, display: 'inline-block' }}>
                          ✓ Aktif Varış Tesisi
                        </span>
                      ) : (
                        <button
                          onClick={() => setSelectedFacility(fac.id)}
                          style={{ marginTop: 4, width: '100%', background: '#7C3AED', color: 'white', fontSize: 11, fontWeight: 700, padding: '4px 8px', borderRadius: 6, border: 'none', cursor: 'pointer' }}
                        >
                          Hedef Tesis Olarak Seç →
                        </button>
                      )}
                    </div>
                  </Popup>
                </Marker>
              )
            })}

          {/* ── 3. HARİTADAKİ TÜM KUTULAR (Doluluk & Rota Durakları) ── */}
          {bins.map(bin => {
            if (typeof bin.latitude !== 'number' || typeof bin.longitude !== 'number') return null
            const occ = calcOccupancy(bin)
            const waypointIndex = currentRoute?.waypoints ? currentRoute.waypoints.findIndex(w => w.bin_id === bin.bin_id) : -1
            const isInRoute = waypointIndex !== -1
            const isCollected = collectedIdSet.has(bin.bin_id) || occ === 0
            const isSelected = selectedBinIds.includes(bin.bin_id)

            // Diğer aktif rotadaki durağı kontrol et
            let otherDepotStopInfo = null
            if (!isInRoute) {
              Object.entries(routes).forEach(([dKey, r]) => {
                if (dKey !== selectedDepot && r?.routeCoords && !r.completed) {
                  const idx = r.waypoints.findIndex(w => w.bin_id === bin.bin_id)
                  if (idx !== -1) {
                    otherDepotStopInfo = {
                      depotKey: dKey,
                      stopNum: idx + 1,
                      depotName: r.shortName || dKey,
                      color: '#22C55E',
                      isCollected: r.collectedBinIds.includes(bin.bin_id),
                    }
                  }
                }
              })
            }

            const icon = isInRoute
              ? createWaypointIcon(occ, waypointIndex + 1, isCollected, '#22C55E')
              : otherDepotStopInfo
              ? createWaypointIcon(occ, otherDepotStopInfo.stopNum, otherDepotStopInfo.isCollected, otherDepotStopInfo.color)
              : createBinIcon(bin.type, occ, isCollected, isSelected, '#2563EB')

            return (
              <Marker
                key={bin.bin_id ?? `bin_${Math.random()}`}
                position={[bin.latitude, bin.longitude]}
                icon={icon}
              >
                <Popup>
                  <div className="min-w-[170px]">
                    <p className="font-bold text-dark text-sm">{bin.name || bin.bin_id}</p>
                    <p className="text-xs text-gray-400 font-mono">{bin.bin_id}</p>
                    {bin.semt && <p className="text-xs text-gray-500 mt-0.5">📍 {bin.semt}</p>}
                    <div className="flex items-center gap-2 mt-2">
                      <div
                        className={`text-white text-xs font-bold px-2 py-0.5 rounded-full flex items-center gap-1 ${
                          isCollected ? 'bg-emerald-500' : occ >= 0.85 ? 'bg-red-500' : 'bg-amber-500'
                        }`}
                      >
                        {isCollected ? '✓ %0 Temiz' : `${toPercent(occ)} Dolu`}
                      </div>
                      <span className="text-xs text-gray-500">
                        {bin.type === 'private' ? 'Özel' : 'Topluma Açık'}
                      </span>
                    </div>

                    {isInRoute ? (
                      <p className="text-xs font-bold mt-1.5 text-emerald-700">
                        {isCollected ? '✅ Durak Tamamlandı' : `🚩 ${currentDepotConfig.shortName} Durak #${waypointIndex + 1}`}
                      </p>
                    ) : otherDepotStopInfo ? (
                      <p className="text-xs font-bold mt-1.5 text-amber-600">
                        🔒 {otherDepotStopInfo.depotName} Durak #{otherDepotStopInfo.stopNum} (Atandı)
                      </p>
                    ) : isSelected ? (
                      <p className="text-xs font-bold mt-1.5 text-blue-600">
                        ✨ {currentDepotConfig.shortName} Rotasına Seçildi
                      </p>
                    ) : null}
                  </div>
                </Popup>
              </Marker>
            )
          })}

          {/* ── 4. OLUŞTURULAN ROTALAR (TÜMÜ DAİMA AÇIK YEŞİL RENKTE) ── */}
          {activeRoutesList.map(([depotKey, route]) => {
            const depotInfo = DEPOTS[depotKey] || {}
            const polyline = route.routeCoords.map(([lng, lat]) => [lat, lng])

            return (
              <div key={depotKey}>
                {/* Her depo ve tesis rotası daima açık yeşil (#22C55E) renkte */}
                <Polyline
                  positions={polyline}
                  color="#22C55E"
                  weight={5}
                  opacity={0.9}
                />
                {route.truckPosition && (
                  <Marker
                    position={route.truckPosition}
                    icon={depotTruckIcon(depotInfo)}
                    zIndexOffset={1000}
                  >
                    <Popup>
                      <div className="text-center font-sans p-1">
                        <p className="font-bold text-dark">{depotInfo.name || `${depotKey} Aracı`}</p>
                        <p className="text-xs text-emerald-700 font-semibold mt-0.5">
                          İlerleme: %{Math.round(route.progress * 100)} ({route.waypoints.length} Durak)
                        </p>
                      </div>
                    </Popup>
                  </Marker>
                )}
              </div>
            )
          })}
        </MapContainer>

        {/* ───── 5. YENİ SAĞ ALT KÖŞE: Sabitlenmiş Bağımsız "Filo Takip / Aktif Filolar" Paneli ───── */}
        <div className="absolute bottom-6 right-6 z-[1000] w-[340px] sm:w-[380px] bg-white/95 backdrop-blur-md border border-gray-200/90 rounded-2xl shadow-2xl overflow-hidden transition-all duration-300">
          {/* Widget Başlığı */}
          <div className="p-3.5 bg-gradient-to-r from-gray-900 to-slate-800 text-white flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="w-8 h-8 rounded-xl bg-amber-400/20 text-amber-300 flex items-center justify-center shrink-0">
                <Zap className="w-4 h-4" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="font-extrabold text-sm tracking-tight leading-none">Aktif Filolar</h3>
                  <span className="bg-emerald-500/30 text-emerald-300 border border-emerald-400/40 text-[10px] font-extrabold px-1.5 py-0.5 rounded-full">
                    {activeRoutesList.length} Filo
                  </span>
                </div>
                <p className="text-[11px] text-gray-300 mt-0.5">Eşzamanlı Takip & Kontrol</p>
              </div>
            </div>

            <div className="flex items-center gap-1.5">
              {readyRoutesCount > 1 && (
                <button
                  onClick={startAllFleets}
                  className="text-[10px] font-bold text-emerald-300 hover:text-white flex items-center gap-1 bg-emerald-500/20 hover:bg-emerald-500/30 border border-emerald-400/30 px-2 py-1 rounded-lg transition-colors cursor-pointer"
                  title="Tüm hazır araçları aynı anda rotaya başlatır"
                >
                  <Play className="w-2.5 h-2.5" /> Tümünü Başlat
                </button>
              )}

              <button
                onClick={() => setIsFleetWidgetMinimized(v => !v)}
                className="p-1.5 rounded-lg hover:bg-white/10 text-gray-300 hover:text-white transition-colors cursor-pointer"
                title={isFleetWidgetMinimized ? 'Genişlet' : 'Küçült'}
              >
                {isFleetWidgetMinimized ? <ChevronUp className="w-4 h-4" /> : <ChevronDown className="w-4 h-4" />}
              </button>
            </div>
          </div>

          {/* Widget Gövdesi (Açılır/Kapanır) */}
          {!isFleetWidgetMinimized && (
            <div className="p-3.5 space-y-2.5 max-h-72 overflow-y-auto">
              {activeRoutesList.length === 0 ? (
                <div className="bg-gray-50/90 border border-dashed border-gray-200 rounded-xl p-4 text-center">
                  <div className="w-10 h-10 rounded-xl bg-gray-100 flex items-center justify-center mx-auto text-gray-400 mb-2">
                    <Truck className="w-5 h-5" />
                  </div>
                  <p className="text-gray-700 font-bold text-xs">Aktif Filo Bulunmuyor</p>
                  <p className="text-[11px] text-gray-400 mt-0.5 leading-relaxed">
                    Sol panelden kutuları seçip "Rotayı Optimize Et" dediğinizde araçlar burada anlık olarak listelenecektir.
                  </p>
                </div>
              ) : (
                activeRoutesList.map(([depotKey, r]) => {
                  const isSelected = selectedDepot === depotKey
                  const isMoving = r.isPlaying
                  const isDone = r.completed
                  const depotInfo = DEPOTS[depotKey] || {}

                  return (
                    <div
                      key={depotKey}
                      onClick={() => setSelectedDepot(depotKey)}
                      className={`p-3 rounded-xl border transition-all cursor-pointer ${
                        isSelected
                          ? 'bg-blue-50/70 border-blue-400 shadow-sm ring-1 ring-blue-300'
                          : 'bg-white border-gray-200 hover:border-gray-300 hover:bg-gray-50/50'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2 min-w-0">
                          <span className="text-base">{r.truckEmoji || '🚚'}</span>
                          <div className="min-w-0">
                            <p className="text-xs font-bold text-dark truncate">
                              {r.shortName || depotInfo.shortName || depotKey}
                            </p>
                            <p className="text-[10px] text-gray-400 truncate">
                              Hedef: {r.facilityShortName || 'Tesis'}
                            </p>
                          </div>
                        </div>

                        <div className="flex items-center gap-1.5">
                          <span
                            className={`text-[9px] font-extrabold px-2 py-0.5 rounded-full ${
                              isMoving
                                ? 'bg-emerald-100 text-emerald-700 animate-pulse'
                                : isDone
                                ? 'bg-blue-100 text-blue-700'
                                : 'bg-amber-100 text-amber-700'
                            }`}
                          >
                            {isMoving ? 'Yolda' : isDone ? 'Tamam' : 'Bekliyor'}
                          </span>

                          <button
                            onClick={(e) => {
                              e.stopPropagation()
                              togglePlay(depotKey)
                            }}
                            disabled={isDone}
                            className="p-1.5 rounded-lg bg-gray-100 hover:bg-gray-200 text-gray-700 disabled:opacity-30 cursor-pointer transition-colors"
                            title={isMoving ? 'Durdur' : 'Başlat'}
                          >
                            {isMoving ? <Square className="w-3.5 h-3.5 text-amber-600" /> : <Play className="w-3.5 h-3.5 text-emerald-600" />}
                          </button>
                        </div>
                      </div>

                      {/* İlerleme Çubuğu (Açık Yeşil Rota Uyumu) */}
                      <div className="mt-2">
                        <div className="flex justify-between text-[10px] text-gray-500 mb-1">
                          <span>{r.waypoints.length} Durak</span>
                          <span className="font-mono font-bold text-dark">%{Math.round(r.progress * 100)}</span>
                        </div>
                        <div className="w-full bg-gray-100 rounded-full h-1.5 overflow-hidden">
                          <div
                            className="h-full rounded-full transition-all duration-300"
                            style={{
                              width: `${r.progress * 100}%`,
                              backgroundColor: '#22C55E',
                            }}
                          />
                        </div>
                      </div>
                    </div>
                  )
                })
              )}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
