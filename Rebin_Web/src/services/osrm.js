import axios from 'axios'

const OSRM_BASE = 'http://router.project-osrm.org/route/v1/driving'
const OSRM_TABLE_BASE = 'http://router.project-osrm.org/table/v1/driving'

/**
 * İki nokta arası Haversine (kuş uçuşu) mesafesini metre cinsinden hesaplar
 */
export function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000 // Dünya yarıçapı (metre)
  const dLat = ((lat2 - lat1) * Math.PI) / 180
  const dLon = ((lon2 - lon1) * Math.PI) / 180
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2)
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
  return R * c
}

/**
 * OSRM Table API'nin ulaşılamadığı durumlarda yedek seyahat matrisi oluşturur
 */
export function generateFallbackTable(waypoints) {
  const n = waypoints.length
  const durations = Array.from({ length: n }, () => Array(n).fill(0))
  const distances = Array.from({ length: n }, () => Array(n).fill(0))

  // Şehir içi sürüş katsayısı: 1.35x yol viraj payı, ~30 km/s ortalama hız (8.33 m/s)
  const ROAD_FACTOR = 1.35
  const SPEED_MPS = 8.33

  for (let i = 0; i < n; i++) {
    for (let j = 0; j < n; j++) {
      if (i === j) continue
      const dist = calculateHaversineDistance(
        waypoints[i].lat,
        waypoints[i].lng,
        waypoints[j].lat,
        waypoints[j].lng
      ) * ROAD_FACTOR
      distances[i][j] = Math.round(dist)
      durations[i][j] = Math.round(dist / SPEED_MPS)
    }
  }

  return { durations, distances, fallback: true }
}

/**
 * OSRM Table API (/table/v1/driving/) kullanarak NxN süre ve mesafe matrisi alır
 * @param {Array<{lat: number, lng: number}>} waypoints - Noktalar listesi
 * @param {string} annotations - 'duration,distance' veya 'duration'
 * @returns {Promise<{durations: number[][], distances: number[][], fallback: boolean}>}
 */
export async function getTable(waypoints, annotations = 'duration,distance') {
  if (!waypoints || waypoints.length < 2) {
    throw new Error('Mesafe matrisi için en az 2 nokta gereklidir')
  }

  const coords = waypoints
    .map(wp => `${wp.lng},${wp.lat}`)
    .join(';')

  const url = `${OSRM_TABLE_BASE}/${coords}?annotations=${annotations}`

  try {
    const response = await axios.get(url, { timeout: 10000 })
    if (response.data?.code === 'Ok' && Array.isArray(response.data?.durations)) {
      return {
        durations: response.data.durations,
        distances: response.data.distances || response.data.durations,
        fallback: false,
      }
    }
  } catch (err) {
    console.warn('OSRM Table API yanıt vermedi veya limit aşıldı, Haversine yedek matrisi kullanılıyor:', err?.message)
  }

  // API hatasında sistemi durdurmamak için güvenilir Haversine fallback matrisi döndür
  return generateFallbackTable(waypoints)
}

/**
 * OSRM'den gerçek sokak rotası al
 * @param {Array<{lat: number, lng: number}>} waypoints - Sıralı waypoint listesi
 * @returns {Promise<{geometry: GeoJSON, distance: number, duration: number, legs: Array}>}
 */
export async function getRoute(waypoints) {
  if (waypoints.length < 2) throw new Error('En az 2 waypoint gerekli')

  // OSRM format: "lng,lat;lng,lat;..."
  const coords = waypoints
    .map(wp => `${wp.lng},${wp.lat}`)
    .join(';')

  const url = `${OSRM_BASE}/${coords}?overview=full&geometries=geojson&steps=true`

  const response = await axios.get(url, { timeout: 15000 })

  if (response.data.code !== 'Ok') {
    throw new Error(`OSRM Hatası: ${response.data.message || response.data.code}`)
  }

  const route = response.data.routes[0]
  return {
    geometry: route.geometry,              // GeoJSON LineString
    distance: route.distance,              // metre cinsinden
    duration: route.duration,             // saniye cinsinden
    legs: route.legs,                     // Ara duraklar arası bilgi
    coordinates: route.geometry.coordinates, // [[lng, lat], ...]
  }
}

/**
 * Metre cinsinden mesafeyi km formatında döndür
 */
export function formatDistance(meters) {
  if (meters < 1000) return `${Math.round(meters)} m`
  return `${(meters / 1000).toFixed(1)} km`
}

/**
 * Saniye cinsinden süreyi dakika formatında döndür
 */
export function formatDuration(seconds) {
  const mins = Math.round(seconds / 60)
  if (mins < 60) return `${mins} dk`
  const h = Math.floor(mins / 60)
  const m = mins % 60
  return `${h} sa ${m} dk`
}

