import { getTable } from './osrm.js'

/**
 * ─────────────────────────────────────────────────────────────────────────────
 * ROTA OPTİMİZASYON SERVİSİ
 * ─────────────────────────────────────────────────────────────────────────────
 * 1. OSRM Table API ile gerçek yol seyahat süresi (Travel Time) NxN matrisi.
 * 2. N <= 12 durak için Held-Karp Dinamik Programlama (Exact Global Minimum).
 * 3. Çapraz geçişleri ve U dönüşlerini önlemek için 2-Opt Yerel Arama (Local Search).
 * 4. N > 12 durak için Ölçeklenebilir Nearest-Neighbor + 2-Opt + Simulated Annealing.
 * ─────────────────────────────────────────────────────────────────────────────
 */

/**
 * Belirli bir durak sırasının toplam maliyetini matris üzerinden hesaplar
 * @param {number[]} tour - Nokta indeksleri dizisi [0, ..., end]
 * @param {number[][]} matrix - NxN maliyet matrisi
 * @returns {number} Toplam maliyet
 */
export function calculateTourCost(tour, matrix) {
  let total = 0
  for (let i = 0; i < tour.length - 1; i++) {
    const from = tour[i]
    const to = tour[i + 1]
    total += matrix[from]?.[to] ?? 0
  }
  return total
}

/**
 * 2-Opt Yerel Arama Algoritması (Local Search Heuristic)
 * Çapraz hat kesişimlerini (cross-edges) ve döngü hatalarını tespit edip segmentleri ters çevirerek (swap)
 * toplam yol maliyetini yerel minimuma indirir.
 *
 * @param {number[]} initialTour - [startIdx, ...stopIndices, endIdx]
 * @param {number[][]} matrix - NxN seyahat matrisi
 * @param {number} maxIterations - Maksimum optimizasyon turu
 * @returns {{ tour: number[], cost: number, swapsApplied: number }}
 */
export function runTwoOptLocalSearch(initialTour, matrix, maxIterations = 500) {
  const n = initialTour.length
  if (n <= 3) {
    return {
      tour: [...initialTour],
      cost: calculateTourCost(initialTour, matrix),
      swapsApplied: 0,
    }
  }

  let tour = [...initialTour]
  let bestCost = calculateTourCost(tour, matrix)
  let swapsApplied = 0
  let iteration = 0
  let improved = true

  // Başlangıç ve bitiş noktaları sabit tutulur (i = 1'den başlar, j <= n - 2'ye kadar gider)
  while (improved && iteration < maxIterations) {
    improved = false
    iteration++

    for (let i = 1; i < n - 2; i++) {
      for (let j = i + 1; j < n - 1; j++) {
        // [i ... j] aralığını ters çevirmenin maliyet farkını hesapla
        // Mevcut segment maliyeti: (i-1 -> i) + (i...j segmenti) + (j -> j+1)
        let oldSegmentCost = matrix[tour[i - 1]][tour[i]] + matrix[tour[j]][tour[j + 1]]
        let newSegmentCost = matrix[tour[i - 1]][tour[j]] + matrix[tour[i]][tour[j + 1]]

        // İç segmentin yönlü maliyetlerini topla (yol yönü tek yön/asimetrik olabilir)
        for (let k = i; k < j; k++) {
          oldSegmentCost += matrix[tour[k]][tour[k + 1]]
          newSegmentCost += matrix[tour[k + 1]][tour[k]]
        }

        const delta = newSegmentCost - oldSegmentCost

        // Eğer ters çevirme maliyeti düşürüyorsa (çapraz kesişim çözülüyorsa) swap uygula
        if (delta < -0.001) {
          // tour[i ... j] aralığını ters çevir
          const reversedSegment = tour.slice(i, j + 1).reverse()
          tour = [
            ...tour.slice(0, i),
            ...reversedSegment,
            ...tour.slice(j + 1),
          ]
          bestCost += delta
          swapsApplied++
          improved = true
          break
        }
      }
      if (improved) break
    }
  }

  return { tour, cost: bestCost, swapsApplied }
}

/**
 * Held-Karp Dinamik Programlama (Bitmask DP) ile Tam TSP Çözücü
 * N <= 12 durak için O(K^2 * 2^K) karmaşıklığında teorik GLOBAL EN KISA rotayı garanti eder.
 *
 * @param {number} startIdx - Başlangıç noktası matris indeksi (Genellikle 0: Depo)
 * @param {number[]} stopIndices - Ziyaret edilecek durakların matris indeksleri
 * @param {number} endIdx - Bitiş noktası matris indeksi (Depo veya Tesis)
 * @param {number[][]} matrix - NxN seyahat süresi/mesafe matrisi
 * @returns {{ order: number[], cost: number }}
 */
export function solveHeldKarpTSP(startIdx, stopIndices, endIdx, matrix) {
  const K = stopIndices.length
  if (K === 0) return { order: [], cost: 0 }
  if (K === 1) {
    const cost = matrix[startIdx][stopIndices[0]] + matrix[stopIndices[0]][endIdx]
    return { order: [stopIndices[0]], cost }
  }

  const numStates = 1 << K

  // dp[mask][lastStopIndexInK]: min maliyet
  // parent[mask][lastStopIndexInK]: önceki durak indeksi
  const dp = Array.from({ length: numStates }, () => new Float64Array(K).fill(Infinity))
  const parent = Array.from({ length: numStates }, () => new Int16Array(K).fill(-1))

  // Başlangıç durumları: Start noktasından ilk durağa geçiş
  for (let i = 0; i < K; i++) {
    const mask = 1 << i
    dp[mask][i] = matrix[startIdx][stopIndices[i]]
    parent[mask][i] = -1
  }

  // Dinamik Programlama geçişleri (küçük alt kümelerden büyük alt kümelere)
  for (let mask = 1; mask < numStates; mask++) {
    for (let u = 0; u < K; u++) {
      if ((mask & (1 << u)) === 0) continue
      const currentCost = dp[mask][u]
      if (!Number.isFinite(currentCost)) continue

      const uMatrixIdx = stopIndices[u]

      // Henüz ziyaret edilmemiş v durağına geçiş dene
      for (let v = 0; v < K; v++) {
        if ((mask & (1 << v)) !== 0) continue

        const nextMask = mask | (1 << v)
        const vMatrixIdx = stopIndices[v]
        const newCost = currentCost + matrix[uMatrixIdx][vMatrixIdx]

        if (newCost < dp[nextMask][v]) {
          dp[nextMask][v] = newCost
          parent[nextMask][v] = u
        }
      }
    }
  }

  // Tüm duraklar ziyaret edildiğinde (fullMask) bitiş noktasına bağlan
  const fullMask = numStates - 1
  let bestCost = Infinity
  let bestLast = -1

  for (let u = 0; u < K; u++) {
    const totalCost = dp[fullMask][u] + matrix[stopIndices[u]][endIdx]
    if (totalCost < bestCost) {
      bestCost = totalCost
      bestLast = u
    }
  }

  // Geriye doğru yolu yeniden oluştur
  const order = []
  let cur = bestLast
  let curMask = fullMask

  while (cur !== -1) {
    order.unshift(stopIndices[cur])
    const prev = parent[curMask][cur]
    curMask = curMask ^ (1 << cur)
    cur = prev
  }

  return { order, cost: bestCost }
}

/**
 * Yüksek durak sayısı (N > 12) için Ölçeklenebilir Meta-Sezgisel Çözücü
 * (Nearest Neighbor Başlangıcı + 2-Opt Yerel Arama + Simulated Annealing)
 *
 * @param {number} startIdx
 * @param {number[]} stopIndices
 * @param {number} endIdx
 * @param {number[][]} matrix
 * @returns {{ order: number[], cost: number, swapsApplied: number }}
 */
export function solveMetaheuristicTSP(startIdx, stopIndices, endIdx, matrix) {
  const K = stopIndices.length
  if (K <= 1) return { order: [...stopIndices], cost: 0, swapsApplied: 0 }

  // 1. Açgözlü En Yakın Komşu (Greedy Nearest Neighbor) ile başlangıç çözümü oluştur
  const remaining = new Set(stopIndices)
  const initialStops = []
  let current = startIdx

  while (remaining.size > 0) {
    let nearest = null
    let minCost = Infinity
    for (const candidate of remaining) {
      const cost = matrix[current][candidate]
      if (cost < minCost) {
        minCost = cost
        nearest = candidate
      }
    }
    initialStops.push(nearest)
    remaining.delete(nearest)
    current = nearest
  }

  let currentTour = [startIdx, ...initialStops, endIdx]

  // 2. İlk 2-Opt yerel arama turu
  let { tour: optTour, cost: optCost, swapsApplied: totalSwaps } = runTwoOptLocalSearch(currentTour, matrix)

  // 3. Simulated Annealing (Tavlama Benzetimi) ile yerel tuzaklardan kurtulma
  let temperature = 100.0
  const coolingRate = 0.94
  const minTemp = 0.5
  let bestTour = [...optTour]
  let bestCost = optCost

  while (temperature > minTemp) {
    for (let step = 0; step < 20; step++) {
      // 1 ile K arasında rastgele 2 indeks seç ve ters çevir
      const i = 1 + Math.floor(Math.random() * (K - 1))
      const j = i + 1 + Math.floor(Math.random() * (K - i))
      if (j >= optTour.length - 1) continue

      const neighbor = [
        ...optTour.slice(0, i),
        ...optTour.slice(i, j + 1).reverse(),
        ...optTour.slice(j + 1),
      ]

      const neighborCost = calculateTourCost(neighbor, matrix)
      const delta = neighborCost - optCost

      if (delta < 0 || Math.random() < Math.exp(-delta / temperature)) {
        optTour = neighbor
        optCost = neighborCost
        if (neighborCost < bestCost) {
          bestTour = [...neighbor]
          bestCost = neighborCost
        }
      }
    }
    temperature *= coolingRate
  }

  // 4. En iyi çözüm üzerinde son 2-Opt temizleme geçişi
  const finalResult = runTwoOptLocalSearch(bestTour, matrix)

  return {
    order: finalResult.tour.slice(1, -1),
    cost: finalResult.cost,
    swapsApplied: totalSwaps + finalResult.swapsApplied,
  }
}

/**
 * Ana Rota Optimizatörü (OSRM Table API + Held-Karp / 2-Opt)
 *
 * @param {Object} params
 * @param {{lat: number, lng: number, name?: string}} params.start - Başlangıç Deposu
 * @param {Array<{lat: number, lng: number, bin_id?: string, name?: string}>} params.stops - Toplanacak Kutular
 * @param {{lat: number, lng: number, name?: string}|null} params.end - Bitiş Noktası (Tesis veya Başlangıç Deposu)
 * @param {'duration'|'distance'} [params.metric='duration'] - Minimize edilecek hedef metrik
 * @returns {Promise<{
 *   orderedStops: Array<any>,
 *   fullWaypoints: Array<any>,
 *   metrics: {
 *     algorithm: string,
 *     isExact: boolean,
 *     stopsCount: number,
 *     matrixSource: string,
 *     initialCost: number,
 *     optimizedCost: number,
 *     costImprovement: number,
 *     improvementPercent: number,
 *     swapsApplied: number,
 *     computationTimeMs: number,
 *     isClosedLoop: boolean
 *   }
 * }>}
 */
export async function optimizeStopSequence({
  start,
  stops,
  end = null,
  metric = 'duration',
}) {
  const startTime = performance.now()

  if (!stops || stops.length === 0) {
    return {
      orderedStops: [],
      fullWaypoints: end ? [start, end] : [start, start],
      metrics: {
        algorithm: 'None',
        isExact: true,
        stopsCount: 0,
        matrixSource: 'None',
        initialCost: 0,
        optimizedCost: 0,
        costImprovement: 0,
        improvementPercent: 0,
        swapsApplied: 0,
        computationTimeMs: 0,
        isClosedLoop: !end || (start.lat === end.lat && start.lng === end.lng),
      },
    }
  }

  // Hedef bitiş noktası: Belirtilmemişse veya başlangıçla aynıysa kapalı döngü (Closed TSP)
  const isClosedLoop = !end || (Math.abs(start.lat - end.lat) < 1e-6 && Math.abs(start.lng - end.lng) < 1e-6)
  const targetEnd = isClosedLoop ? start : end

  // Tüm lokasyonları matris için hazırla:
  // [0: Start, 1..K: Stops, (K+1: End eğer açık TSP ise)]
  const allLocations = [start, ...stops]
  let endMatrixIdx = 0

  if (!isClosedLoop) {
    allLocations.push(targetEnd)
    endMatrixIdx = allLocations.length - 1
  }

  // 1. OSRM Table API'den NxN Seyahat Matrisini çek (durations ve distances)
  const tableData = await getTable(allLocations, 'duration,distance')
  const matrix = metric === 'distance' ? tableData.distances : tableData.durations
  const matrixSource = tableData.fallback ? 'Haversine Fallback' : 'OSRM Table API'

  const stopIndices = stops.map((_, idx) => idx + 1)
  const initialTour = [0, ...stopIndices, endMatrixIdx]
  const initialCost = calculateTourCost(initialTour, matrix)

  let orderedIndices = []
  let algorithm = ''
  let isExact = false
  let swapsApplied = 0

  // 2. Dinamik Çözücü Seçimi:
  // N <= 12 durak ise Held-Karp Dinamik Programlama (Global Optimum Garanti)
  if (stops.length <= 12) {
    algorithm = 'Held-Karp Dinamik Programlama (Global Optimum)'
    isExact = true
    const hkResult = solveHeldKarpTSP(0, stopIndices, endMatrixIdx, matrix)

    // 3. 2-Opt yerel arama ile çapraz hatların temizlendiğini doğrula / parlat
    const postTwoOpt = runTwoOptLocalSearch([0, ...hkResult.order, endMatrixIdx], matrix)
    orderedIndices = postTwoOpt.tour.slice(1, -1)
    swapsApplied = postTwoOpt.swapsApplied
  } else {
    // N > 12 durak ise Ölçeklenebilir Meta-Sezgisel (Nearest-Neighbor + 2-Opt + Simulated Annealing)
    algorithm = 'Ölçeklenebilir 2-Opt + Simulated Annealing'
    isExact = false
    const metaResult = solveMetaheuristicTSP(0, stopIndices, endMatrixIdx, matrix)
    orderedIndices = metaResult.order
    swapsApplied = metaResult.swapsApplied
  }

  const finalTour = [0, ...orderedIndices, endMatrixIdx]
  const optimizedCost = calculateTourCost(finalTour, matrix)
  const costImprovement = Math.max(0, initialCost - optimizedCost)
  const improvementPercent = initialCost > 0 ? Math.round((costImprovement / initialCost) * 100) : 0

  // İndeksleri orijinal durak nesnelerine dönüştür
  const orderedStops = orderedIndices.map(idx => stops[idx - 1])
  const fullWaypoints = [start, ...orderedStops, targetEnd]

  const endTime = performance.now()
  const computationTimeMs = Math.round((endTime - startTime) * 10) / 10

  return {
    orderedStops,
    fullWaypoints,
    metrics: {
      algorithm,
      isExact,
      stopsCount: stops.length,
      matrixSource,
      initialCost: Math.round(initialCost),
      optimizedCost: Math.round(optimizedCost),
      costImprovement: Math.round(costImprovement),
      improvementPercent,
      swapsApplied,
      computationTimeMs,
      isClosedLoop,
    },
  }
}
