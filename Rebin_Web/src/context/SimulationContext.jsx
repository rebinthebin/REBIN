import { createContext, useContext, useState, useEffect, useRef, useCallback } from 'react'
import { fetchBins, insertBin, fetchAllDepolar, fetchAllTesisler } from '../services/supabase'
import { getRoute } from '../services/osrm'
import { optimizeStopSequence } from '../services/routeOptimizer'
import {
  calcOccupancy,
  CITIES,
  DEPOTS,
  FACILITIES,
  getBinCity,
  isSimulationBin,
  randomCoordInBounds,
} from '../utils/binUtils'

const SimulationContext = createContext(null)

let simCounter = 0

// Başlangıç Depo Rota Şablonu (Rota renkleri daima açık yeşil)
const createEmptyRoute = (depotKey = 'A', allDepolarList = []) => {
  const dbDepo = (allDepolarList || []).find(d => String(d.id) === String(depotKey))
  const depotObj = dbDepo
    ? {
        name: dbDepo.depo_adi,
        shortName: dbDepo.semt || dbDepo.depo_adi,
        city: (dbDepo.city || '').toLowerCase().includes('ank') ? 'ankara' : 'istanbul',
        truckEmoji: '🚚',
      }
    : (DEPOTS[depotKey] || DEPOTS.A)

  return {
    depotKey: String(depotKey),
    depotName: depotObj.name,
    shortName: depotObj.shortName || String(depotKey),
    city: depotObj.city,
    color: '#22C55E', // Daima açık yeşil
    truckEmoji: depotObj.truckEmoji || '🚚',
    routeCoords: null,
    routeInfo: null,
    waypoints: [],
    waypointIndices: [],
    isPlaying: false,
    currentIndex: 0,
    progress: 0,
    completed: false,
    truckPosition: null,
    collectedBinIds: [],
    routeError: null,
    calculating: false,
  }
}

// Tüm depolar için boş rota haritası üret
const buildInitialRoutes = () => {
  const r = {}
  Object.keys(DEPOTS).forEach(key => {
    r[key] = createEmptyRoute(key)
  })
  return r
}

export function SimulationProvider({ children }) {
  const [bins, setBins] = useState([])
  const [loadingBins, setLoadingBins] = useState(true)
  const [binsError, setBinsError] = useState(null)

  // Aktif Seçili Şehir & Depo & Tesis
  const [selectedCity, setSelectedCity] = useState('istanbul')
  const [selectedDepot, setSelectedDepot] = useState('A')
  const [selectedFacilities, setSelectedFacilities] = useState({
    istanbul: 'ist_avrupa',
  })

  // Depo bazlı bağımsız ve eşzamanlı rota / filo yönetimi (routes['A'], routes['B'], routes['A2'], routes['B2'])
  const [routes, setRoutes] = useState(buildInitialRoutes)

  // Supabase'den gelen depo ve tesis verileri (Sadece gerçek Supabase verileri)
  const [allDepolar, setAllDepolar] = useState([])
  const [allTesisler, setAllTesisler] = useState([])
  const [dbDepolar, setDbDepolar] = useState([])
  const [dbTesisler, setDbTesisler] = useState([])
  const [dbLoading, setDbLoading] = useState(false)

  // Kutuları Supabase'den veya yerelden yükleme
  const refreshBins = useCallback(async () => {
    try {
      setLoadingBins(true)
      const data = await fetchBins()
      setBins(data || [])
    } catch (err) {
      console.error('Kutular yüklenirken hata:', err)
      setBinsError(err.message)
    } finally {
      setLoadingBins(false)
    }
  }, [])

  useEffect(() => {
    refreshBins()
  }, [refreshBins])

  // Supabase'den tüm depoları ve tesisleri çek (Sadece Supabase'deki gerçek veriler)
  const refreshDbLocations = useCallback(async () => {
    try {
      setDbLoading(true)
      const [depolar, tesisler] = await Promise.all([
        fetchAllDepolar(),
        fetchAllTesisler(),
      ])
      setAllDepolar(Array.isArray(depolar) ? depolar : [])
      setAllTesisler(Array.isArray(tesisler) ? tesisler : [])
    } catch (err) {
      console.warn('[SimulationContext] refreshDbLocations hatası:', err)
    } finally {
      setDbLoading(false)
    }
  }, [])

  useEffect(() => {
    refreshDbLocations()
  }, [refreshDbLocations])

  // Şehir veya lokasyon listesi güncellendiğinde seçili şehre ait depoları ve tesisleri filtrele
  useEffect(() => {
    const isAnk = selectedCity === 'ankara'
    const filteredDepolar = allDepolar.filter(d =>
      isAnk ? (d.city || '').toLowerCase().includes('ank') : (d.city || '').toLowerCase().includes('ist')
    )
    const filteredTesisler = allTesisler.filter(t =>
      isAnk ? (t.city || '').toLowerCase().includes('ank') : (t.city || '').toLowerCase().includes('ist')
    )
    setDbDepolar(filteredDepolar)
    setDbTesisler(filteredTesisler)

    // Seçili depo mevcut şehirde geçerli mi kontrol et; değilse şehrin ilk deposunu seç
    const currentDepotValid = filteredDepolar.some(d => String(d.id) === String(selectedDepot)) ||
      Object.keys(DEPOTS).some(k => k === selectedDepot && DEPOTS[k].city === selectedCity)

    if (!currentDepotValid) {
      if (filteredDepolar.length > 0) {
        setSelectedDepot(String(filteredDepolar[0].id))
      } else {
        const cityDepotKeys = Object.keys(DEPOTS).filter(k => DEPOTS[k].city === selectedCity)
        if (cityDepotKeys.length > 0) {
          setSelectedDepot(cityDepotKeys[0])
        }
      }
    }

    // Seçili tesis mevcut şehirde geçerli mi kontrol et; değilse şehrin ilk tesisini seç
    const currentFacId = selectedFacilities[selectedCity]
    if (currentFacId !== 'depot_return') {
      const currentFacValid = filteredTesisler.some(t => String(t.id) === String(currentFacId)) ||
        FACILITIES.some(f => f.id === currentFacId && f.city === selectedCity)

      if (!currentFacValid) {
        if (filteredTesisler.length > 0) {
          setSelectedFacilities(prev => ({
            ...prev,
            [selectedCity]: String(filteredTesisler[0].id),
          }))
        } else {
          const staticFac = FACILITIES.find(f => f.city === selectedCity)
          if (staticFac) {
            setSelectedFacilities(prev => ({
              ...prev,
              [selectedCity]: staticFac.id,
            }))
          }
        }
      }
    }
  }, [selectedCity, allDepolar, allTesisler, selectedDepot, selectedFacilities])

  // Şehir değiştiğinde ilgili şehrin ilk deposunu ve tesisini seç
  const handleSelectCity = useCallback((city) => {
    setSelectedCity(city)
    const isAnk = city === 'ankara'
    const cityDepolar = allDepolar.filter(d =>
      isAnk ? (d.city || '').toLowerCase().includes('ank') : (d.city || '').toLowerCase().includes('ist')
    )
    if (cityDepolar.length > 0) {
      setSelectedDepot(String(cityDepolar[0].id))
    } else {
      const cityDepotKeys = Object.keys(DEPOTS).filter(k => DEPOTS[k].city === city)
      if (cityDepotKeys.length > 0) {
        setSelectedDepot(cityDepotKeys[0])
      }
    }

    const cityTesisler = allTesisler.filter(t =>
      isAnk ? (t.city || '').toLowerCase().includes('ank') : (t.city || '').toLowerCase().includes('ist')
    )
    if (cityTesisler.length > 0) {
      setSelectedFacilities(prev => ({
        ...prev,
        [city]: String(cityTesisler[0].id),
      }))
    } else {
      const staticFac = FACILITIES.find(f => f.city === city)
      if (staticFac) {
        setSelectedFacilities(prev => ({
          ...prev,
          [city]: staticFac.id,
        }))
      }
    }
  }, [allDepolar, allTesisler])

  // Depo değiştiğinde şehrin senkronize edilmesi
  const handleSelectDepot = useCallback((depotKey) => {
    const keyStr = String(depotKey)
    setSelectedDepot(keyStr)

    const dbDepo = allDepolar.find(d => String(d.id) === keyStr)
    if (dbDepo) {
      const depoCity = (dbDepo.city || '').toLowerCase().includes('ank') ? 'ankara' : 'istanbul'
      if (depoCity !== selectedCity) {
        setSelectedCity(depoCity)
      }
      return
    }
    const depotObj = DEPOTS[keyStr]
    if (depotObj && depotObj.city !== selectedCity) {
      setSelectedCity(depotObj.city)
    }
  }, [allDepolar, selectedCity])

  // Tesis / Varış Noktası Seçimi (Geri Dönüşüm Tesisi veya Döngüsel Depo Dönüşü)
  const handleSelectFacility = useCallback((facilityId) => {
    const facIdStr = String(facilityId)
    if (facIdStr === 'depot_return') {
      setSelectedFacilities(prev => ({
        ...prev,
        [selectedCity]: 'depot_return',
      }))
      return
    }

    // Önce Supabase tesislerinde ara
    const dbFac = allTesisler.find(t => String(t.id) === facIdStr)
    if (dbFac) {
      const facCity = (dbFac.city || '').toLowerCase().includes('ank') ? 'ankara' : 'istanbul'
      setSelectedFacilities(prev => ({
        ...prev,
        [facCity]: facIdStr,
      }))
      if (facCity !== selectedCity) {
        setSelectedCity(facCity)
      }
      return
    }

    // Statik tesislerde ara
    const fac = FACILITIES.find(f => f.id === facIdStr)
    if (fac) {
      setSelectedFacilities(prev => ({
        ...prev,
        [fac.city]: facIdStr,
      }))
      if (fac.city !== selectedCity) {
        setSelectedCity(fac.city)
      }
    }
  }, [allTesisler, selectedCity])

  // Rastgele 5 Kutu Ekle (Haritanın o anki görünür sınırları içine ekler)
  const addRandomBins = useCallback(async (city = selectedCity, mapBounds = null) => {
    simCounter++
    const newBins = []
    const semtsIstanbul = ['Kadıköy', 'Beşiktaş', 'Üsküdar', 'Fatih', 'Şişli', 'Bakırköy']
    const semtsAnkara = ['Çankaya', 'Keçiören', 'Yenimahalle', 'Mamak', 'Etimesgut']
    const semtList = city === 'ankara' ? semtsAnkara : semtsIstanbul

    for (let i = 0; i < 5; i++) {
      const coords = randomCoordInBounds(mapBounds, city)

      // İlk 3 kutu >%75 (0.76 - 0.98), son 2 kutu rastgele (<%75)
      const isHigh = i < 3
      const randHigh = () => 0.76 + Math.random() * 0.22 // %76 - %98
      const randLow = () => 0.15 + Math.random() * 0.55  // %15 - %70

      const occ_g = isHigh ? randHigh() : randLow()
      const occ_m = isHigh ? randHigh() : randLow()
      const occ_p = isHigh ? randHigh() : randLow()
      const occ_pl = isHigh ? randHigh() : randLow()

      const semt = semtList[Math.floor(Math.random() * semtList.length)]

      const binData = {
        name: `Simülasyon Kutu ${simCounter}-${i + 1} (${city === 'ankara' ? 'Ankara' : 'İst'})`,
        type: Math.random() > 0.5 ? 'private' : 'public',
        is_active: true,
        latitude: coords.lat,
        longitude: coords.lng,
        occupancy_glass: occ_g,
        occupancy_metal: occ_m,
        occupancy_paper: occ_p,
        occupancy_plastic: occ_pl,
        last_emptying: null,
        semt,
        last_updated: new Date().toISOString(),
      }

      try {
        const inserted = await insertBin(binData)
        newBins.push(inserted ?? { ...binData, bin_id: `sim_${simCounter}_${i}_${Date.now()}` })
      } catch {
        newBins.push({ ...binData, bin_id: `sim_${simCounter}_${i}_${Date.now()}` })
      }
    }

    setBins(prev => [...newBins, ...prev])
    return newBins
  }, [selectedCity])

  // Simülasyon kutularını temizle ve tüm rotaları sıfırla
  const clearSimulationBins = useCallback(() => {
    setBins(prev => prev.filter(b => !isSimulationBin(b)))
    setRoutes(buildInitialRoutes())
  }, [])

  // Rota Hesaplama (OSRM Table API + Held-Karp TSP / 2-Opt Destekli)
  const calculateRoute = useCallback(async (customDepot = selectedDepot, selectedBinIds = null, customFacilityId = null) => {
    const targetDepotKey = customDepot || selectedDepot || 'A'

    // DB-first: depo koordinatlarını Supabase'den bul, yoksa statik DEPOTS'dan al
    let depot = null
    if (dbDepolar.length > 0) {
      const dbDepo = dbDepolar.find(d => String(d.id) === targetDepotKey)
      if (dbDepo) {
        depot = {
          lat: dbDepo.latitude,
          lng: dbDepo.longitude,
          name: dbDepo.depo_adi,
          shortName: dbDepo.semt || dbDepo.depo_adi,
          city: dbDepo.city?.toLowerCase().includes('ank') ? 'ankara' : 'istanbul',
          color: '#2563EB',
          truckEmoji: '🚚',
        }
      }
    }
    if (!depot) {
      depot = DEPOTS[targetDepotKey] || DEPOTS.A
    }
    const targetCity = depot.city

    const facId = customFacilityId || selectedFacilities[targetCity] || 'ist_avrupa'
    const isReturnToDepot = facId === 'depot_return' || facId === targetDepotKey

    let destination = null
    if (isReturnToDepot) {
      destination = {
        id: 'depot_return',
        lat: depot.lat,
        lng: depot.lng,
        name: `${depot.name} (Döngüsel TSP Dönüşü)`,
        shortName: `${depot.shortName || targetDepotKey} Depo Dönüşü`,
        city: targetCity,
        isDepot: true,
      }
    } else {
      // DB-first: önce Supabase tesisler tablosunda ara, yoksa statik FACILITIES'e dön
      let facility = null
      if (dbTesisler.length > 0) {
        const dbFac = dbTesisler.find(t => String(t.id) === facId)
        if (dbFac) {
          facility = {
            id: String(dbFac.id),
            lat: dbFac.latitude,
            lng: dbFac.longitude,
            name: dbFac.tesis_adi,
            shortName: dbFac.semt || dbFac.tesis_adi,
            region: dbFac.semt,
            city: dbFac.city,
            color: '#16A34A',
          }
        }
      }
      if (!facility) {
        // Sadece İstanbul tesisleri (FACILITIES artık Ankara içermiyor)
        facility = FACILITIES.find(f => f.id === facId) || (FACILITIES.length > 0 ? FACILITIES[0] : null)
      }
      if (!facility) {
        setRoutes(prev => ({
          ...prev,
          [targetDepotKey]: {
            ...(prev[targetDepotKey] || createEmptyRoute(targetDepotKey)),
            calculating: false,
            routeError: 'Varış tesisi bulunamadı. Lütfen Supabase "tesisler" tablosuna kayıt ekleyin.',
          },
        }))
        return
      }
      destination = {
        ...facility,
        isFacility: true,
      }
    }

    setRoutes(prev => ({
      ...prev,
      [targetDepotKey]: {
        ...(prev[targetDepotKey] || createEmptyRoute(targetDepotKey)),
        calculating: true,
        routeError: null,
        completed: false,
        isPlaying: false,
        currentIndex: 0,
        progress: 0,
        collectedBinIds: [],
      },
    }))

    // Diğer aktif depolara atanmış kutu ID'lerini belirle
    const lockedByOtherDepots = new Set()
    Object.entries(routes).forEach(([dKey, r]) => {
      if (dKey !== targetDepotKey && r?.routeCoords && !r.completed) {
        r.waypoints.forEach(w => {
          if (!r.collectedBinIds.includes(w.bin_id)) {
            lockedByOtherDepots.add(w.bin_id)
          }
        })
      }
    })

    // Rota için kullanılacak kutuları belirle (Diğer depolara atanmış olanlar filtrelenir)
    let targetBins = []
    if (Array.isArray(selectedBinIds) && selectedBinIds.length > 0) {
      const idSet = new Set(selectedBinIds)
      targetBins = bins.filter(b => idSet.has(b.bin_id) && !lockedByOtherDepots.has(b.bin_id) && typeof b.latitude === 'number' && typeof b.longitude === 'number')
    } else {
      // Seçim verilmemişse hedef şehirdeki, doluluğu >= %75 olan ve başka depoya kilitlenmemiş tüm kutuları al
      targetBins = bins.filter(b => {
        const cityMatch = getBinCity(b) === targetCity
        const occOk = calcOccupancy(b) >= 0.75
        const hasCoords = typeof b.latitude === 'number' && typeof b.longitude === 'number'
        const notLocked = !lockedByOtherDepots.has(b.bin_id)
        return cityMatch && occOk && hasCoords && notLocked
      })
    }

    if (targetBins.length === 0) {
      setRoutes(prev => ({
        ...prev,
        [targetDepotKey]: {
          ...(prev[targetDepotKey] || createEmptyRoute(targetDepotKey)),
          calculating: false,
          routeError: `Rotaya eklenecek uygun kutu bulunamadı (Kutular başka depoya atanmış olabilir). Lütfen yeni kutu seçin veya "+5 Kutu Ekle" yapın.`,
        },
      }))
      return
    }

    // Start, Stops ve End objelerini optimizasyon servisi için biçimlendir
    const startNode = {
      lat: depot.lat,
      lng: depot.lng,
      name: depot.name,
      isDepot: true,
    }

    const stopNodes = targetBins.map(b => ({
      lat: b.latitude,
      lng: b.longitude,
      name: b.name || b.bin_id,
      bin_id: b.bin_id,
      bin: b,
    }))

    const endNode = {
      lat: destination.lat,
      lng: destination.lng,
      name: destination.name,
      isFacility: !isReturnToDepot,
      isDepot: isReturnToDepot,
    }

    try {
      // 1. OSRM Table API NxN Matrisi + Held-Karp TSP / 2-Opt Yerel Arama ile En Kısa Rota Sırası
      const optimization = await optimizeStopSequence({
        start: startNode,
        stops: stopNodes,
        end: endNode,
        metric: 'duration',
      })

      const orderedTargetBins = optimization.orderedStops.map(s => s.bin)
      const waypointsList = optimization.fullWaypoints

      // 2. OSRM'den optimize edilmiş durak sırasına göre gerçek sokak rotası çek
      const result = await getRoute(waypointsList)
      const coords = result.coordinates || []

      // Her kutu için rotadaki en yakın koordinat indeksini belirle
      const indices = orderedTargetBins.map(bin => {
        let closestIdx = 0
        let minDistance = Infinity
        coords.forEach(([lng, lat], idx) => {
          const d = Math.hypot(lat - bin.latitude, lng - bin.longitude)
          if (d < minDistance) {
            minDistance = d
            closestIdx = idx
          }
        })
        return { bin_id: bin.bin_id, index: closestIdx }
      })

      const initialPos = coords.length > 0 ? [coords[0][1], coords[0][0]] : null

      setRoutes(prev => ({
        ...prev,
        [targetDepotKey]: {
          depotKey: targetDepotKey,
          depotName: depot.name,
          shortName: depot.shortName || targetDepotKey,
          city: targetCity,
          color: '#22C55E', // Daima açık yeşil
          truckEmoji: depot.truckEmoji || '🚚',
          facilityId: destination.id,
          facilityName: destination.name,
          facilityShortName: destination.shortName,
          isReturnToDepot,
          calculating: false,
          routeError: null,
          routeCoords: coords,
          routeInfo: {
            distance: result.distance,
            duration: result.duration,
            stops: orderedTargetBins.length,
            optimization: optimization.metrics,
          },
          waypoints: orderedTargetBins,
          waypointIndices: indices,
          isPlaying: false,
          currentIndex: 0,
          progress: 0,
          completed: false,
          truckPosition: initialPos,
          collectedBinIds: [],
        },
      }))
    } catch (err) {
      console.error('Rota hesaplama hatası:', err)
      setRoutes(prev => ({
        ...prev,
        [targetDepotKey]: {
          ...(prev[targetDepotKey] || createEmptyRoute(targetDepotKey)),
          calculating: false,
          routeError: err.message || 'Rota hesaplanırken bir hata oluştu.',
        },
      }))
    }
  }, [bins, selectedDepot, selectedFacilities, routes, allDepolar, allTesisler, dbDepolar, dbTesisler])

  // Tekil Rota Sıfırlama
  const resetRoute = useCallback((depotKey = selectedDepot) => {
    setRoutes(prev => ({
      ...prev,
      [depotKey]: createEmptyRoute(depotKey),
    }))
  }, [selectedDepot])

  // Animasyon Oynat/Durdur (Depo bazlı)
  const togglePlay = useCallback((depotKey = selectedDepot) => {
    setRoutes(prev => {
      const route = prev[depotKey]
      if (!route || !route.routeCoords || route.completed) return prev
      return {
        ...prev,
        [depotKey]: {
          ...route,
          isPlaying: !route.isPlaying,
        },
      }
    })
  }, [selectedDepot])

  const startSimulation = useCallback((depotKey = selectedDepot) => {
    setRoutes(prev => {
      const route = prev[depotKey]
      if (!route || !route.routeCoords || route.completed) return prev
      return {
        ...prev,
        [depotKey]: {
          ...route,
          isPlaying: true,
        },
      }
    })
  }, [selectedDepot])

  const pauseSimulation = useCallback((depotKey = selectedDepot) => {
    setRoutes(prev => {
      const route = prev[depotKey]
      if (!route) return prev
      return {
        ...prev,
        [depotKey]: {
          ...route,
          isPlaying: false,
        },
      }
    })
  }, [selectedDepot])

  // Tüm Hazır Araçları Eşzamanlı Başlat / Durdur
  const startAllFleets = useCallback(() => {
    setRoutes(prev => {
      const updated = { ...prev }
      let changed = false
      Object.keys(updated).forEach(k => {
        if (updated[k].routeCoords && !updated[k].completed) {
          updated[k] = { ...updated[k], isPlaying: true }
          changed = true
        }
      })
      return changed ? updated : prev
    })
  }, [])

  const pauseAllFleets = useCallback(() => {
    setRoutes(prev => {
      const updated = { ...prev }
      let changed = false
      Object.keys(updated).forEach(k => {
        if (updated[k].isPlaying) {
          updated[k] = { ...updated[k], isPlaying: false }
          changed = true
        }
      })
      return changed ? updated : prev
    })
  }, [])

  // Kutuyu boşalt / sıfırla yardımcı fonksiyonu
  const emptyBinsList = useCallback((binIds) => {
    if (!binIds || binIds.length === 0) return
    const idSet = new Set(binIds)

    setBins(prevBins =>
      prevBins.map(b => {
        if (idSet.has(b.bin_id)) {
          return {
            ...b,
            occupancy_glass: 0,
            occupancy_metal: 0,
            occupancy_paper: 0,
            occupancy_plastic: 0,
            last_emptying: new Date().toISOString(),
          }
        }
        return b
      })
    )
  }, [])

  // Arka planda BÜTÜN aktif depolar için bağımsız ve senkron çalışan çoklu araç motoru
  useEffect(() => {
    const stepInterval = 160
    let lastTick = Date.now()

    const tick = () => {
      const now = Date.now()
      const elapsed = now - lastTick
      lastTick = now

      // Chrome sekmesi arka plana atıldığında setInterval yavaşlatılır (throttling).
      // Zaman farkını ölçerek aracın kaç adım ilerlemesi gerektiğini hesaplayıp telafi ediyoruz:
      const stepsToAdvance = Math.max(1, Math.floor(elapsed / stepInterval))

      setRoutes(prevRoutes => {
        let hasActive = false
        const updated = { ...prevRoutes }
        const newlyEmptiedIds = []

        Object.entries(prevRoutes).forEach(([depotKey, route]) => {
          // Eğer rota tamamlanmışsa ve üzerinden 4 saniye geçmişse sıfırla
          if (route.completed && route.completedAt) {
            if (now - route.completedAt > 4000) {
              updated[depotKey] = createEmptyRoute(depotKey)
              hasActive = true
            }
            return
          }

          if (!route.isPlaying || !route.routeCoords || route.routeCoords.length < 2 || route.completed) {
            return
          }

          hasActive = true
          const total = route.routeCoords.length
          let nextIndex = route.currentIndex + stepsToAdvance
          let isFinished = false

          if (nextIndex >= total - 1) {
            nextIndex = total - 1
            isFinished = true
          }

          const [lng, lat] = route.routeCoords[nextIndex]
          const newlyCollected = []

          route.waypointIndices.forEach(({ bin_id, index }) => {
            if (nextIndex >= index && !route.collectedBinIds.includes(bin_id)) {
              newlyCollected.push(bin_id)
            }
          })

          if (newlyCollected.length > 0) {
            newlyEmptiedIds.push(...newlyCollected)
          }

          updated[depotKey] = {
            ...route,
            currentIndex: nextIndex,
            truckPosition: [lat, lng],
            progress: nextIndex / (total - 1),
            collectedBinIds: Array.from(new Set([...route.collectedBinIds, ...newlyCollected])),
            isPlaying: !isFinished,
            completed: isFinished,
            completedAt: isFinished ? now : null,
          }
        })

        if (newlyEmptiedIds.length > 0) {
          emptyBinsList(newlyEmptiedIds)
        }

        return hasActive ? updated : prevRoutes
      })
    }

    const intervalId = setInterval(tick, stepInterval)
    
    // Kullanıcı sekmeye geri döndüğünde (veya pencereyi öne aldığında) anında güncelle
    const handleVisibility = () => {
      if (document.visibilityState === 'visible') {
        tick()
      }
    }
    document.addEventListener('visibilitychange', handleVisibility)

    return () => {
      clearInterval(intervalId)
      document.removeEventListener('visibilitychange', handleVisibility)
    }
  }, [emptyBinsList])

  // Aktif seçili deponun nesnesi (DB-first, yoksa DEPOTS)
  const currentDbDepo = allDepolar.find(d => String(d.id) === String(selectedDepot))
  const currentDepotObj = currentDbDepo
    ? {
        id: String(currentDbDepo.id),
        name: currentDbDepo.depo_adi,
        shortName: currentDbDepo.semt || currentDbDepo.depo_adi,
        city: (currentDbDepo.city || '').toLowerCase().includes('ank') ? 'ankara' : 'istanbul',
        lat: currentDbDepo.latitude,
        lng: currentDbDepo.longitude,
        color: '#2563EB',
        truckEmoji: '🚚',
      }
    : (DEPOTS[selectedDepot] || Object.values(DEPOTS).find(d => d.city === selectedCity) || DEPOTS.A)

  const currentRoute = routes[selectedDepot] || createEmptyRoute(selectedDepot, allDepolar)

  const currentFacilityId = selectedFacilities[selectedCity] ||
    (dbTesisler.length > 0 ? String(dbTesisler[0].id) : (FACILITIES.find(f => f.city === selectedCity)?.id || 'ist_avrupa'))

  const currentDbFacility = allTesisler.find(t => String(t.id) === String(currentFacilityId))
  const currentFacility = currentFacilityId === 'depot_return'
    ? {
        id: 'depot_return',
        name: `${currentDepotObj.name} (Döngüsel TSP Dönüşü)`,
        shortName: `${currentDepotObj.shortName || selectedDepot} (Döngü)`,
        region: 'Döngüsel TSP',
        city: selectedCity,
        color: '#22C55E',
        isDepot: true,
      }
    : (
        currentDbFacility
          ? {
              id: String(currentDbFacility.id),
              name: currentDbFacility.tesis_adi,
              shortName: currentDbFacility.semt || currentDbFacility.tesis_adi,
              region: currentDbFacility.semt,
              city: currentDbFacility.city,
              lat: currentDbFacility.latitude,
              lng: currentDbFacility.longitude,
              color: '#16A34A',
            }
          : (FACILITIES.find(f => f.id === currentFacilityId) || FACILITIES.find(f => f.city === selectedCity) || (FACILITIES.length > 0 ? FACILITIES[0] : null))
      )

  return (
    <SimulationContext.Provider
      value={{
        bins,
        setBins,
        loadingBins,
        binsError,
        refreshBins,
        addRandomBins,
        clearSimulationBins,
        selectedCity,
        setSelectedCity: handleSelectCity,
        selectedDepot,
        setSelectedDepot: handleSelectDepot,
        selectedFacilityId: currentFacilityId,
        selectedFacility: currentFacility,
        setSelectedFacility: handleSelectFacility,
        selectedFacilities,

        // Supabase'den gelen gerçek depo ve tesis verileri (Tüm 8 lokasyon ve şehre göre filtrelenmiş)
        allDepolar,
        allTesisler,
        dbDepolar,
        dbTesisler,
        dbLoading,
        refreshDbLocations,

        // Tüm Çoklu Rota / Filo Verileri
        routes,
        currentRoute,

        // Aktif Seçili Deponun Kısayolları
        routeCoords: currentRoute.routeCoords,
        routeInfo: currentRoute.routeInfo,
        waypoints: currentRoute.waypoints,
        waypointIndices: currentRoute.waypointIndices,
        collectedBinIds: new Set(currentRoute.collectedBinIds || []),
        calculating: currentRoute.calculating,
        routeError: currentRoute.routeError,
        isPlaying: currentRoute.isPlaying,
        currentIndex: currentRoute.currentIndex,
        progress: currentRoute.progress,
        completed: currentRoute.completed,
        truckPosition: currentRoute.truckPosition,

        // Fonksiyonlar
        calculateRoute,
        resetRoute,
        togglePlay,
        startSimulation,
        pauseSimulation,
        startAllFleets,
        pauseAllFleets,
      }}
    >
      {children}
    </SimulationContext.Provider>
  )
}

export function useSimulation() {
  const context = useContext(SimulationContext)
  if (!context) {
    throw new Error('useSimulation must be used within a SimulationProvider')
  }
  return context
}

