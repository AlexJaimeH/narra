/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Paleta oficial de Narra (Aqua/Teal)
        brand: {
          primary: '#4DB3A8',         // Teal/Aqua principal
          'primary-solid': '#38827A', // Teal oscuro
          'primary-hover': '#2F6B64', // Teal hover
          'primary-light': '#E0F5F3', // Teal muy claro
          'primary-pale': '#F0FAF9',  // Teal casi blanco
          accent: '#00EAD8',          // Cyan brillante
        },
        text: {
          primary: '#1F2937',         // Texto principal
          secondary: '#6B7280',       // Texto secundario
          light: '#9CA3AF',           // Texto claro
        },
        surface: {
          light: '#FAFAFA',           // Fondo claro
          white: '#FFFFFF',           // Blanco
          gray: '#F3F4F6',            // Gris claro
        },
      },
      fontFamily: {
        sans: ['Montserrat', 'system-ui', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
