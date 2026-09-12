import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://spmyeaixfdiohkmmfvgu.supabase.co'
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNwbXllYWl4ZmRpb2hrbW1mdmd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYwMTY1NzEsImV4cCI6MjEwMTU5MjU3MX0.wcoZ8uYNZa_9Ugp2iZBdtNxCz9lBHR67_V5GK7kuPcA'

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Tüm kutuları çek
export async function fetchBins() {
  const { data, error } = await supabase
    .from('rebins')
    .select(
      'bin_id, name, type, is_active, status, latitude, longitude, last_updated, last_emptying, ' +
      'occupancy_plastic, occupancy_paper, occupancy_glass, occupancy_metal, qr_image_url, semt'
    )
    .order('last_updated', { ascending: false })
  if (error) throw error
  return data
}

// Tek kutu detayı
export async function fetchBinById(binId) {
  const { data, error } = await supabase
    .from('rebins')
    .select(
      'bin_id, name, type, is_active, status, latitude, longitude, last_updated, last_emptying, ' +
      'occupancy_plastic, occupancy_paper, occupancy_glass, occupancy_metal, qr_image_url, semt'
    )
    .eq('bin_id', binId)
    .single()
  if (error) throw error
  return data
}

// Kutu ID ve güvenlik kodu ile kutu doğrula
export async function verifyAndAddBin(binId, qrToken) {
  const { data, error } = await supabase
    .from('rebins')
    .select(
      'bin_id, name, type, is_active, latitude, longitude, last_updated, last_emptying, ' +
      'occupancy_plastic, occupancy_paper, occupancy_glass, occupancy_metal, qr_image_url, semt'
    )
    .eq('bin_id', binId)
    .eq('qr_token', qrToken)
    .single()
  if (error || !data) throw new Error('Kutu bulunamadı. Kutu ID veya güvenlik kodu hatalı.')
  return data
}

// Kutunun fotoğraflarını çek
export async function fetchBinImages(binId) {
  const { data, error } = await supabase
    .from('bin_images')
    .select('*')
    .eq('bin_id', binId)
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

// Kutunun aktif durumunu güncelle
export async function toggleBinActive(binId, isActive) {
  const { data, error } = await supabase
    .from('rebins')
    .update({ is_active: isActive })
    .eq('bin_id', binId)
    .select()
    .single()
  if (error) throw error
  return data
}

// Storage'dan resim URL'i al
export async function fetchSemtOptions() {
  const { data, error } = await supabase
    .from('rebins')
    .select('semt')
    .neq('semt', null)
    .order('semt')
  if (error) throw error
  // Return distinct semt values
  const semtSet = new Set(data.map((row) => row.semt))
  return Array.from(semtSet)
}

export async function insertBin(newBin) {
  const { data, error } = await supabase
    .from('rebins')
    .insert([newBin])
    .select(
      'bin_id, name, type, is_active, latitude, longitude, last_updated, last_emptying, ' +
      'occupancy_plastic, occupancy_paper, occupancy_glass, occupancy_metal, qr_image_url, semt'
    )
    .single()
  if (error) throw error
  return data
}

export function getStorageImageUrl(path) {
  const { data } = supabase.storage
    .from('rebin-images')
    .getPublicUrl(path)
  return data.publicUrl
}

// Tek kutunun hata sayaçlarını çek
export async function fetchBinErrors(binId) {
  const { data, error } = await supabase
    .from('bin_errors')
    .select('bin_id, error_1, error_2, error_3, error_4, last_reported_at')
    .eq('bin_id', binId)
    .maybeSingle()
  if (error) throw error
  return data
}

// Birden fazla kutu için tüm hata kayıtlarını çek
export async function fetchAllBinErrors() {
  const { data, error } = await supabase
    .from('bin_errors')
    .select('bin_id, error_1, error_2, error_3, error_4, last_reported_at')
  if (error) throw error
  return data ?? []
}

// Kutunun tüm arıza sayaçlarını sıfırla
export async function clearBinErrors(binId) {
  const { data, error } = await supabase
    .from('bin_errors')
    .update({
      error_1: 0,
      error_2: 0,
      error_3: 0,
      error_4: 0,
    })
    .eq('bin_id', binId)
    .select()
    .single()
  if (error) throw error
  return data
}

// Tüm depoları çek (depolar tablosu: id, depo_adi, semt, city, latitude, longitude)
export async function fetchAllDepolar() {
  try {
    const { data, error } = await supabase
      .from('depolar')
      .select('id, depo_adi, semt, city, latitude, longitude')
      .order('id')
    if (error) {
      console.warn('[supabase] depolar tablosu sorgulanamadı:', error.message)
      return []
    }
    return data ?? []
  } catch (err) {
    console.warn('[supabase] fetchAllDepolar hatası:', err.message)
    return []
  }
}

// Tüm tesisleri çek (tesisler tablosu: id, tesis_adi, semt, city, latitude, longitude)
export async function fetchAllTesisler() {
  try {
    const { data, error } = await supabase
      .from('tesisler')
      .select('id, tesis_adi, semt, city, latitude, longitude')
      .order('id')
    if (error) {
      console.warn('[supabase] tesisler tablosu sorgulanamadı:', error.message)
      return []
    }
    return data ?? []
  } catch (err) {
    console.warn('[supabase] fetchAllTesisler hatası:', err.message)
    return []
  }
}

// Şehre göre depolar çek (depolar tablosu: id, depo_adi, semt, city, latitude, longitude)
export async function fetchDepolarByCity(city) {
  try {
    const { data, error } = await supabase
      .from('depolar')
      .select('id, depo_adi, semt, city, latitude, longitude')
      .ilike('city', city)
      .order('depo_adi')
    if (error) {
      console.warn('[supabase] depolar tablosu sorgulanamadı:', error.message)
      return []
    }
    return data ?? []
  } catch (err) {
    console.warn('[supabase] fetchDepolarByCity hatası:', err.message)
    return []
  }
}

// Şehre göre tesisler çek (tesisler tablosu: id, tesis_adi, semt, city, latitude, longitude)
export async function fetchTesislerByCity(city) {
  try {
    const { data, error } = await supabase
      .from('tesisler')
      .select('id, tesis_adi, semt, city, latitude, longitude')
      .ilike('city', city)
      .order('tesis_adi')
    if (error) {
      console.warn('[supabase] tesisler tablosu sorgulanamadı:', error.message)
      return []
    }
    return data ?? []
  } catch (err) {
    console.warn('[supabase] fetchTesislerByCity hatası:', err.message)
    return []
  }
}
