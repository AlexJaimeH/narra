/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          primary: '#4DB3A8',      // Teal/Aqua principal
          'primary-solid': '#38827A',
          'primary-hover': '#2F6B64',
          accent: '#00EAD8',        // Cyan accent
          secondary: '#B5846E',     // Marrón
          'secondary-solid': '#966D5B',
          'secondary-hover': '#815B4C',
        },
        text: {
          primary: '#333333',
          secondary: '#666666',
          light: '#999999',
        },
        surface: {
          light: '#FAFAFA',
          paper: '#F8F8F8',
          dark: '#1A1A1A',
        },
      },
      fontFamily: {
        sans: ['Montserrat', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
