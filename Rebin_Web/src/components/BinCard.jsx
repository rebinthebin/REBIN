import { useNavigate } from 'react-router-dom'
import { MapPin, Calendar, Eye, AlertTriangle } from 'lucide-react'
import CircularProgress from './CircularProgress'
import { calcOccupancy, formatDate, WASTE_COLORS, WASTE_BG_COLORS, WASTE_LABELS } from '../utils/binUtils'

const wasteFields = [
  { key: 'plastic', field: 'occupancy_plastic' },
  { key: 'paper',   field: 'occupancy_paper' },
  { key: 'glass',   field: 'occupancy_glass' },
  { key: 'metal',   field: 'occupancy_metal' },
]

/**
 * binErrors: { error_1, error_2, error_3, error_4 } | null | undefined
 * Eğer kutunun status === 'out_of_order' ise VEYA herhangi bir hata sayacı > 0 ise
 * kart sarı/amber temalı görünür ve "ARIZALI !" rozeti gösterilir.
 */
export default function BinCard({ bin, binErrors, onShowMap }) {
  const navigate = useNavigate()
  const occupancy = calcOccupancy(bin)

  // Arızalı mı?
  const hasError =
    bin.status === 'out_of_order' ||
    (binErrors &&
      ((binErrors.error_1 ?? 0) > 0 ||
        (binErrors.error_2 ?? 0) > 0 ||
        (binErrors.error_3 ?? 0) > 0 ||
        (binErrors.error_4 ?? 0) > 0))

  // Doluluk rengini belirle
  let ringColor = '#38A169'
  if (occupancy >= 0.85) ringColor = '#EF5350'
  else if (occupancy >= 0.65) ringColor = '#FFCA28'

  // Arızalı ise ring rengi amber/sarı override
  if (hasError) ringColor = '#D97706'

  return (
    <div
      className={`rounded-2xl shadow-card p-5 hover:shadow-lg transition-shadow duration-200 border-2 bg-white ${
        hasError
          ? 'border-amber-500'
          : 'border-gray-100'
      }`}
    >
      {/* Üst Satır: Başlık + Rozetler */}
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-start gap-2">
          {hasError && (
            <AlertTriangle className="w-4 h-4 text-amber-500 mt-0.5 shrink-0" />
          )}
          <div>
            <h3 className="text-base font-bold text-dark leading-tight">{bin.name || bin.bin_id}</h3>
            <p className="text-xs text-gray-400 mt-0.5 font-mono">{bin.bin_id}</p>
          </div>
        </div>
        <div className="flex flex-col items-end gap-1">
          {/* Durum Rozeti */}
          {hasError ? (
            <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-yellow-100 text-yellow-800 flex items-center gap-1">
              <AlertTriangle className="w-3 h-3" />
              ARIZALI !
            </span>
          ) : (
            <span
              className={`text-xs font-semibold px-2 py-0.5 rounded-full ${
                bin.is_active
                  ? 'bg-green-100 text-green-700'
                  : 'bg-red-100 text-red-600'
              }`}
            >
              {bin.is_active ? 'Aktif' : 'Deaktif'}
            </span>
          )}
          <span
            className={`text-xs font-semibold px-2 py-0.5 rounded-full ${
              bin.type === 'private'
                ? 'bg-purple-100 text-purple-700'
                : 'bg-blue-100 text-blue-700'
            }`}
          >
            {bin.type === 'private' ? 'Özel' : 'Topluma Açık'}
          </span>
        </div>
      </div>

      {/* Orta: Büyük Doluluk + 4 Bölme */}
      <div className="flex items-center justify-between gap-4 mb-4">
        {/* Ana Doluluk */}
        <div className="flex flex-col items-center">
          <CircularProgress
            value={occupancy}
            color={ringColor}
            size={90}
            strokeWidth={9}
            label="Genel Doluluk"
            fontSize={15}
          />
        </div>

        {/* 4 Bölme */}
        <div className="grid grid-cols-2 gap-2 flex-1">
          {wasteFields.map(({ key, field }) => (
            <div
              key={key}
              className="flex items-center justify-center p-2 rounded-xl transition-colors duration-200 border border-black/5"
              style={{ backgroundColor: WASTE_BG_COLORS[key] }}
            >
              <CircularProgress
                value={bin[field] ?? 0}
                color={WASTE_COLORS[key]}
                size={52}
                strokeWidth={5}
                label={WASTE_LABELS[key]}
                fontSize={10}
              />
            </div>
          ))}
        </div>
      </div>


      {/* Alt Satır: Son Boşaltım + Butonlar */}
      <div className="flex items-center justify-between pt-3 border-t border-gray-100">
        <div className="flex items-center gap-1.5 text-xs text-gray-500">
          <Calendar className="w-3.5 h-3.5" />
          <span>{formatDate(bin.last_emptying)}</span>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => {
              if (onShowMap) onShowMap(bin)
              else navigate(`/harita?binId=${bin.bin_id}`)
            }}
            className="flex items-center gap-1 text-xs font-medium text-primary hover:text-primary-dark bg-primary/10 hover:bg-primary/20 px-3 py-1.5 rounded-lg transition-colors"
          >
            <MapPin className="w-3.5 h-3.5" />
            Haritada Göster
          </button>
          <button
            onClick={() => navigate(`/bin/${bin.bin_id}`)}
            className="flex items-center gap-1 text-xs font-medium text-gray-600 hover:text-dark bg-gray-100 hover:bg-gray-200 px-3 py-1.5 rounded-lg transition-colors"
          >
            <Eye className="w-3.5 h-3.5" />
            Detay
          </button>
        </div>
      </div>
    </div>
  )
}
