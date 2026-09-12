/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#38A169',
          dark: '#4CAF50',
          light: '#68D391',
        },
        waste: {
          plastic: '#2196F3',
          'plastic-dark': '#3182CE',
          paper: '#FFCA28',
          'paper-dark': '#D69E2E',
          glass: '#66BB6A',
          'glass-dark': '#38A169',
          metal: '#EF5350',
          'metal-dark': '#E53E3E',
        },
        bg: {
          DEFAULT: '#F7FAFC',
          alt: '#F5F5F5',
        },
        dark: '#1A202C',
      },
      borderRadius: {
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
      boxShadow: {
        card: '0 2px 12px 0 rgba(0,0,0,0.08)',
      },
    },
  },
  plugins: [],
}
