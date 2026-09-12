import { useState, useRef, useEffect } from 'react'
import { MapPin, ChevronDown, Check } from 'lucide-react'
import { CITIES } from '../utils/binUtils'

export default function CitySelector({ selectedCity, onSelectCity, className = '' }) {
  const [isOpen, setIsOpen] = useState(false)
  const dropdownRef = useRef(null)

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const currentCity = CITIES[selectedCity] || CITIES.istanbul

  return (
    <div ref={dropdownRef} className={`relative inline-block ${className}`}>
      <button
        type="button"
        onClick={() => setIsOpen(prev => !prev)}
        className="flex items-center gap-2 bg-white hover:bg-gray-50 text-dark border border-gray-200 hover:border-gray-300 px-3.5 py-2 rounded-xl shadow-sm transition-all duration-150 text-xs sm:text-sm font-semibold focus:outline-none focus:ring-2 focus:ring-primary/20"
      >
        <div className="w-5 h-5 rounded-lg bg-primary/10 flex items-center justify-center text-primary shrink-0">
          <MapPin className="w-3.5 h-3.5" />
        </div>
        <span className="truncate">{currentCity.label}</span>
        <ChevronDown className={`w-3.5 h-3.5 text-gray-400 transition-transform duration-200 ${isOpen ? 'rotate-180 text-primary' : ''}`} />
      </button>

      {isOpen && (
        <div className="absolute top-full left-0 sm:right-0 sm:left-auto mt-1.5 w-48 bg-white border border-gray-100 rounded-2xl shadow-xl py-1.5 z-[1000] animate-in fade-in zoom-in-95 duration-150">
          <div className="px-3 py-1.5 border-b border-gray-100 text-[10px] font-bold uppercase tracking-wider text-gray-400">
            Şehir Seçin
          </div>
          {Object.entries(CITIES).map(([key, config]) => {
            const isSelected = selectedCity === key
            return (
              <button
                key={key}
                type="button"
                onClick={() => {
                  onSelectCity(key)
                  setIsOpen(false)
                }}
                className={`w-full text-left px-3.5 py-2 text-xs sm:text-sm flex items-center justify-between transition-colors ${
                  isSelected
                    ? 'bg-primary/10 text-primary font-bold'
                    : 'text-gray-700 hover:bg-gray-50 font-medium'
                }`}
              >
                <div className="flex items-center gap-2">
                  <span className={`w-2 h-2 rounded-full ${isSelected ? 'bg-primary' : 'bg-gray-300'}`} />
                  <span>{config.label}</span>
                </div>
                {isSelected && <Check className="w-4 h-4 text-primary" />}
              </button>
            )
          })}
        </div>
      )}
    </div>
  )
}
