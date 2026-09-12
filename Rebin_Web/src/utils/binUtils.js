/**
 * Kutunun genel doluluk oranını hesapla (0.0 - 1.0)
 * 4 bölmenin ortalaması
 */
export function calcOccupancy(bin) {
  const values = [
    bin.occupancy_glass ?? 0,
    bin.occupancy_metal ?? 0,
    bin.occupancy_paper ?? 0,
    bin.occupancy_plastic ?? 0,
  ]
  return values.reduce((a, b) => a + b, 0) / values.length
}

/**
 * Kutuları genel doluluk oranına göre azalan sırala
 */
/**
 * Kutu arızalı mı? status veya bin_errors sayaçlarından birine bakılır.
 */
export function isBinFaulty(bin, errorsMap = {}) {
  if (bin.status === 'out_of_order') return true
  const e = errorsMap[bin.bin_id]
  if (!e) return false
  return (e.error_1 ?? 0) > 0 || (e.error_2 ?? 0) > 0 || (e.error_3 ?? 0) > 0 || (e.error_4 ?? 0) > 0
}

/**
 * Kutuları genel doluluk oranına göre azalan sırala.
 * Arızalı kutular (errorsMap opsiyonel) her zaman listenin en sonuna konur.
 */
export function sortByOccupancy(bins, errorsMap = {}) {
  return [...bins].sort((a, b) => {
    const aFaulty = isBinFaulty(a, errorsMap)
    const bFaulty = isBinFaulty(b, errorsMap)
    if (aFaulty !== bFaulty) return aFaulty ? 1 : -1
    return calcOccupancy(b) - calcOccupancy(a)
  })
}

/**
 * Timestamp'i Türkçe tarih formatına çevir
 * Örn: "1 Mayıs 2026, 00:00"
 */
export function formatDate(timestamp) {
  if (!timestamp) return 'Bilinmiyor'
  const date = new Date(timestamp)
  return date.toLocaleDateString('tr-TR', {
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  })
}

/**
 * Oranı yüzdeye çevir (0.75 → "75%")
 */
export function toPercent(value, decimals = 0) {
  return `${(value * 100).toFixed(decimals)}%`
}

/**
 * Doluluk oranına göre renk sınıfı döndür
 */
export function occupancyColor(value) {
  if (value >= 0.85) return '#EF5350'   // Kırmızı - kritik
  if (value >= 0.65) return '#FFCA28'   // Sarı - uyarı
  return '#38A169'                       // Yeşil - normal
}

/**
 * Atık türüne göre renk döndür
 * T.C. Çevre, Şehircilik ve İklim Değişikliği Bakanlığı
 * Sıfır Atık Yönetmeliği resmi piktogram renk standartları
 */
export const WASTE_COLORS = {
  plastic: '#1565C0', // Mavi   — Plastik Atıklar
  paper:   '#FBC02D', // Sarı / Turuncu — Kağıt Atıklar
  glass:   '#388E3C', // Canlı Yeşil — Cam Atıklar
  metal:   '#E53935', // Kırmızı / Pembe — Metal Atıklar
}

/** Atık türlerine ait soft zemin renkleri */
export const WASTE_BG_COLORS = {
  plastic: '#EBF3FA', // Açık Mavi
  paper:   '#FFFDE7', // Açık Sarı
  glass:   '#E8F5E9', // Açık Yeşil
  metal:   '#FFEBEE', // Açık Pembe
}

export const WASTE_LABELS = {
  plastic: 'Plastik',
  paper: 'Kağıt',
  glass: 'Cam',
  metal: 'Metal',
}

// Şehir Merkezleri ve Ayarları
export const CITIES = {
  istanbul: { label: 'İstanbul', center: [41.015137, 28.97953], zoom: 12 },
  ankara:   { label: 'Ankara',   center: [39.9334,   32.8597],  zoom: 11 },
}

// Depolar (İstanbul: A, B)
export const DEPOTS = {
  A: {
    lat: 41.0455,
    lng: 29.0120,
    name: 'Depo A (Kadıköy)',
    shortName: 'Depo A',
    city: 'istanbul',
    color: '#2563EB',
    bgColor: 'bg-blue-50',
    borderColor: 'border-blue-500',
    textColor: 'text-blue-600',
    truckEmoji: '🚚',
  },
  B: {
    lat: 41.0700,
    lng: 28.9500,
    name: 'Depo B (Fatih)',
    shortName: 'Depo B',
    city: 'istanbul',
    color: '#0D9488',
    bgColor: 'bg-teal-50',
    borderColor: 'border-teal-500',
    textColor: 'text-teal-600',
    truckEmoji: '🚛',
  },
}

// Ana Geri Dönüşüm Tesisleri (İstanbul: Avrupa, Anadolu)
export const FACILITIES = [
  {
    id: 'ist_avrupa',
    lat: 41.0620,
    lng: 28.8320,
    name: 'Avrupa Geri Dönüşüm Tesisi (Bağcılar)',
    shortName: 'Avrupa Tesisi',
    region: 'Avrupa Yakası',
    city: 'istanbul',
    color: '#7C3AED',
  },
  {
    id: 'ist_anadolu',
    lat: 40.9850,
    lng: 29.1450,
    name: 'Anadolu Geri Dönüşüm Tesisi (Ataşehir)',
    shortName: 'Anadolu Tesisi',
    region: 'Anadolu Yakası',
    city: 'istanbul',
    color: '#9333EA',
  },
]

/**
 * Koordinata göre kutunun hangi şehre ait olduğunu tespit eder
 */
export function getBinCity(bin) {
  if (!bin || typeof bin.latitude !== 'number' || typeof bin.longitude !== 'number') {
    return 'istanbul'
  }
  const lat = bin.latitude
  const lng = bin.longitude

  // Ankara koordinat alanı yaklaşık: lat 39.5-40.5, lng 32.0-33.5
  const dAnkara = Math.hypot(lat - CITIES.ankara.center[0], lng - CITIES.ankara.center[1])
  const dIstanbul = Math.hypot(lat - CITIES.istanbul.center[0], lng - CITIES.istanbul.center[1])
  return dAnkara < dIstanbul ? 'ankara' : 'istanbul'
}

/**
 * Kutunun bir simülasyon kutusu olup olmadığını kontrol eder
 */
export function isSimulationBin(bin) {
  if (!bin) return false
  const idStr = String(bin.bin_id || '')
  return idStr.startsWith('sim_') || bin.name?.includes('Simülasyon')
}

/**
 * Harita sınırları (bounds) içerisinde rastgele koordinat üret
 */
export function randomCoordInBounds(bounds, city = 'istanbul') {
  if (bounds) {
    let sw = null
    let ne = null

    if (typeof bounds.getSouthWest === 'function' && typeof bounds.getNorthEast === 'function') {
      sw = bounds.getSouthWest()
      ne = bounds.getNorthEast()
    } else if (bounds._southWest && bounds._northEast) {
      sw = bounds._southWest
      ne = bounds._northEast
    } else if (typeof bounds.south === 'number' && typeof bounds.north === 'number') {
      sw = { lat: bounds.south, lng: bounds.west }
      ne = { lat: bounds.north, lng: bounds.east }
    }

    if (sw && ne && typeof sw.lat === 'number' && typeof ne.lat === 'number') {
      // Harita kenarlarından hafif (%5) içeriye doğru padding bırak
      const latRange = ne.lat - sw.lat
      const lngRange = ne.lng - sw.lng
      const padLat = latRange * 0.08
      const padLng = lngRange * 0.08

      const minLat = Math.min(sw.lat, ne.lat) + padLat
      const maxLat = Math.max(sw.lat, ne.lat) - padLat
      const minLng = Math.min(sw.lng, ne.lng) + padLng
      const maxLng = Math.max(sw.lng, ne.lng) - padLng

      const lat = minLat + Math.random() * (maxLat - minLat)
      const lng = minLng + Math.random() * (maxLng - minLng)
      return { lat, lng }
    }
  }

  // Fallback: şehir merkezine yakın koordinat
  const center = CITIES[city]?.center || CITIES.istanbul.center
  const lat = center[0] + (Math.random() - 0.5) * 0.08
  const lng = center[1] + (Math.random() - 0.5) * 0.08
  return { lat, lng }
}
