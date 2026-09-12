import { useState } from 'react'
import { Mail, Phone, MapPin, Send, CheckCircle } from 'lucide-react'

export default function IletisimPage() {
  const [form, setForm] = useState({ name: '', email: '', subject: '', message: '' })
  const [sent, setSent] = useState(false)
  const [sending, setSending] = useState(false)

  const handleSubmit = async (e) => {
    e.preventDefault()
    setSending(true)
    // Simüle edilmiş gönderim (gerçek backend entegrasyonu için buraya API çağrısı eklenebilir)
    await new Promise(r => setTimeout(r, 1200))
    setSent(true)
    setSending(false)
  }

  const contactInfo = [
    { icon: Mail, label: 'E-posta', value: 'destek@rebin.com.tr', href: 'mailto:destek@rebin.com.tr' },
    { icon: Phone, label: 'Telefon', value: '+90 212 000 00 00', href: 'tel:+902120000000' },
    { icon: MapPin, label: 'Adres', value: 'İstanbul, Türkiye', href: null },
  ]

  return (
    <div className="max-w-5xl mx-auto px-4 sm:px-6 py-8 page-enter">
      <div className="mb-8">
        <h1 className="text-2xl font-bold text-dark">İletişim</h1>
        <p className="text-gray-500 text-sm mt-1">Sorularınız için bize ulaşın, en kısa sürede dönüş yaparız.</p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* İletişim Bilgileri */}
        <div className="space-y-4">
          {contactInfo.map(({ icon: Icon, label, value, href }) => (
            <div key={label} className="bg-white rounded-2xl shadow-card border border-gray-100 p-5 flex items-start gap-4">
              <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center flex-shrink-0">
                <Icon className="w-5 h-5 text-primary" />
              </div>
              <div>
                <p className="text-xs font-semibold text-gray-400 uppercase tracking-wide">{label}</p>
                {href ? (
                  <a href={href} className="text-sm font-medium text-dark hover:text-primary transition-colors">
                    {value}
                  </a>
                ) : (
                  <p className="text-sm font-medium text-dark">{value}</p>
                )}
              </div>
            </div>
          ))}

          {/* Hızlı Bilgi */}
          <div className="bg-primary/5 border border-primary/20 rounded-2xl p-5">
            <h3 className="font-bold text-dark text-sm mb-2">Rebin Hakkında</h3>
            <p className="text-xs text-gray-600 leading-relaxed">
              Rebin, akıllı geri dönüşüm kutu yönetim sistemidir.
              Belediyeler ve kurumlar için optimize rota planlama,
              doluluk takibi ve atık yönetimi sağlar.
            </p>
          </div>
        </div>

        {/* İletişim Formu */}
        <div className="lg:col-span-2 bg-white rounded-2xl shadow-card border border-gray-100 p-6">
          {sent ? (
            <div className="flex flex-col items-center justify-center h-full py-12 gap-4">
              <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
                <CheckCircle className="w-8 h-8 text-green-500" />
              </div>
              <div className="text-center">
                <h3 className="font-bold text-dark text-lg">Mesajınız İletildi!</h3>
                <p className="text-gray-500 text-sm mt-1">En kısa sürede size dönüş yapacağız.</p>
              </div>
              <button
                onClick={() => { setSent(false); setForm({ name: '', email: '', subject: '', message: '' }) }}
                className="text-primary text-sm font-semibold hover:underline"
              >
                Yeni Mesaj Gönder
              </button>
            </div>
          ) : (
            <form onSubmit={handleSubmit} className="space-y-4">
              <h2 className="font-bold text-dark">Mesaj Gönder</h2>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="text-xs font-semibold text-gray-600 mb-1 block">Ad Soyad *</label>
                  <input
                    type="text"
                    required
                    value={form.name}
                    onChange={e => setForm(f => ({ ...f, name: e.target.value }))}
                    placeholder="Ahmet Yılmaz"
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"
                  />
                </div>
                <div>
                  <label className="text-xs font-semibold text-gray-600 mb-1 block">E-posta *</label>
                  <input
                    type="email"
                    required
                    value={form.email}
                    onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
                    placeholder="ahmet@ornek.com"
                    className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-600 mb-1 block">Konu</label>
                <input
                  type="text"
                  value={form.subject}
                  onChange={e => setForm(f => ({ ...f, subject: e.target.value }))}
                  placeholder="Destek talebi, önerim var..."
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-gray-600 mb-1 block">Mesaj *</label>
                <textarea
                  required
                  rows={5}
                  value={form.message}
                  onChange={e => setForm(f => ({ ...f, message: e.target.value }))}
                  placeholder="Mesajınızı buraya yazın..."
                  className="w-full border border-gray-200 rounded-xl px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-primary/30 focus:border-primary transition-all resize-none"
                />
              </div>

              <button
                type="submit"
                disabled={sending}
                className="w-full flex items-center justify-center gap-2 bg-primary text-white font-semibold py-3 rounded-xl hover:bg-primary-dark transition-colors disabled:opacity-70 text-sm"
              >
                <Send className="w-4 h-4" />
                {sending ? 'Gönderiliyor...' : 'Mesaj Gönder'}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  )
}
