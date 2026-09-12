/**
 * SVG tabanlı dairesel progress bar
 * @param {number} value - 0.0 ile 1.0 arası doluluk oranı
 * @param {string} color - Çember rengi (hex)
 * @param {number} size - SVG boyutu (px)
 * @param {string} label - Ortadaki alt etiket
 * @param {number} strokeWidth - Çember kalınlığı
 * @param {boolean} showPercent - Yüzde göster
 */
export default function CircularProgress({
  value = 0,
  color = '#38A169',
  size = 80,
  label = '',
  strokeWidth = 8,
  showPercent = true,
  fontSize = null,
}) {
  const clamped = Math.min(Math.max(value, 0), 1)
  const radius = (size - strokeWidth) / 2
  const circumference = 2 * Math.PI * radius
  const offset = circumference * (1 - clamped)

  const percentText = `${Math.round(clamped * 100)}%`
  const fs = fontSize || Math.round(size * 0.18)

  return (
    <div className="flex flex-col items-center gap-1">
      <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
        {/* Arka plan halkası */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="#E2E8F0"
          strokeWidth={strokeWidth}
        />
        {/* Doluluk halkası */}
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={strokeWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          style={{ transition: 'stroke-dashoffset 0.6s ease' }}
        />
        {/* Merkez yüzde yazısı */}
        {showPercent && (
          <text
            x={size / 2}
            y={size / 2}
            textAnchor="middle"
            dominantBaseline="central"
            fontSize={fs}
            fontWeight="700"
            fill="#1A202C"
          >
            {percentText}
          </text>
        )}
      </svg>
      {label && (
        <span className="text-xs text-gray-500 font-medium text-center leading-tight">
          {label}
        </span>
      )}
    </div>
  )
}
