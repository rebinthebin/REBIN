import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Navbar from './components/Navbar'
import KutularPage from './pages/KutularPage'
import HaritaPage from './pages/HaritaPage'
import YonetimPage from './pages/YonetimPage'
import BinDetailPage from './pages/BinDetailPage'
import IletisimPage from './pages/IletisimPage'
import { SimulationProvider } from './context/SimulationContext'

export default function App() {
  return (
    <SimulationProvider>
      <BrowserRouter>
        <div className="min-h-screen bg-bg flex flex-col">
          <Navbar />
          <main className="flex-1">
            <Routes>
              <Route path="/" element={<Navigate to="/kutular" replace />} />
              <Route path="/kutular" element={<KutularPage />} />
              <Route path="/harita" element={<HaritaPage />} />
              <Route path="/yonetim" element={<YonetimPage />} />
              <Route path="/bin/:id" element={<BinDetailPage />} />
              <Route path="/iletisim" element={<IletisimPage />} />
              <Route path="*" element={<Navigate to="/kutular" replace />} />
            </Routes>
          </main>
        </div>
      </BrowserRouter>
    </SimulationProvider>
  )
}
