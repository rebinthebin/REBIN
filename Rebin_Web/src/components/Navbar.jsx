import { NavLink } from 'react-router-dom'
import { Recycle, LayoutGrid, Map, Settings, Mail } from 'lucide-react'

const navItems = [
  { to: '/kutular',  label: 'Kutular',  icon: LayoutGrid },
  { to: '/harita',   label: 'Harita',   icon: Map },
  { to: '/yonetim',  label: 'Yönetim',  icon: Settings },
  { to: '/iletisim', label: 'İletişim', icon: Mail },
]

export default function Navbar() {
  return (
    <nav className="sticky top-0 z-50 bg-white border-b border-gray-200 shadow-sm">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <NavLink to="/" className="flex items-center gap-2 group">
            <div className="w-9 h-9 flex items-center justify-center">
              <img src="/rebin_icon.png" alt="Rebin Logo" className="w-full h-full object-contain" />
            </div>
            <span className="text-xl font-bold text-dark tracking-tight">
              Rebin<span className="text-primary">-Web</span>
            </span>
          </NavLink>

          {/* Desktop Nav */}
          <div className="hidden sm:flex items-center gap-1">
            {navItems.map(({ to, label, icon: Icon }) => (
              <NavLink
                key={to}
                to={to}
                className={({ isActive }) =>
                  `flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium transition-all duration-200
                  ${isActive
                    ? 'bg-primary/10 text-primary font-semibold'
                    : 'text-gray-500 hover:text-dark hover:bg-gray-100'
                  }`
                }
              >
                <Icon className="w-4 h-4" />
                {label}
              </NavLink>
            ))}
          </div>

          {/* Mobile Nav */}
          <div className="flex sm:hidden items-center gap-1">
            {navItems.map(({ to, label, icon: Icon }) => (
              <NavLink
                key={to}
                to={to}
                title={label}
                className={({ isActive }) =>
                  `p-2 rounded-xl transition-all duration-200
                  ${isActive
                    ? 'bg-primary/10 text-primary'
                    : 'text-gray-400 hover:text-dark'
                  }`
                }
              >
                <Icon className="w-5 h-5" />
              </NavLink>
            ))}
          </div>
        </div>
      </div>
    </nav>
  )
}
