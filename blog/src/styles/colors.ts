/**
 * Paleta de colores oficial de Narra
 *
 * Esta es la paleta de colores de la marca Narra.
 * Todos los componentes deben usar estos colores para mantener consistencia.
 */

export const NarraColors = {
  // Colores principales de la marca (Aqua/Teal)
  brand: {
    primary: '#4DB3A8',           // Teal/Aqua principal
    primarySolid: '#38827A',      // Teal oscuro sólido
    primaryHover: '#2F6B64',      // Teal hover más oscuro
    accent: '#00EAD8',            // Cyan accent brillante
    primaryLight: '#E0F5F3',      // Teal muy claro para fondos
    primaryPale: '#F0FAF9',       // Teal casi blanco
  },

  // Colores de texto
  text: {
    primary: '#1F2937',           // Texto principal oscuro
    secondary: '#6B7280',         // Texto secundario gris
    light: '#9CA3AF',             // Texto claro
    inverse: '#FFFFFF',           // Texto sobre fondos oscuros
  },

  // Colores de fondo
  surface: {
    light: '#FAFAFA',             // Fondo claro general
    white: '#FFFFFF',             // Blanco puro
    gray: '#F3F4F6',              // Gris claro
    grayDark: '#E5E7EB',          // Gris oscuro
  },

  // Colores de estado
  status: {
    success: '#10B981',           // Verde éxito
    error: '#EF4444',             // Rojo error
    warning: '#F59E0B',           // Amarillo advertencia
    info: '#3B82F6',              // Azul información
  },

  // Colores de interacción
  interactive: {
    heart: '#EF4444',             // Rojo para reacciones de corazón
    heartLight: '#FEE2E2',        // Fondo claro para corazón
    link: '#4DB3A8',              // Color de links (igual a brand primary)
    linkHover: '#38827A',         // Color de links al hover
  },

  // Colores de bordes
  border: {
    light: '#E5E7EB',             // Borde claro
    medium: '#D1D5DB',            // Borde medio
    dark: '#9CA3AF',              // Borde oscuro
    brand: '#4DB3A8',             // Borde con color de marca
  },
} as const;

/**
 * Función helper para crear clases de Tailwind con los colores de Narra
 */
export const narraColor = {
  bg: {
    primary: 'bg-[#4DB3A8]',
    primaryLight: 'bg-[#E0F5F3]',
    primaryPale: 'bg-[#F0FAF9]',
  },
  text: {
    primary: 'text-[#4DB3A8]',
    primaryDark: 'text-[#38827A]',
  },
  border: {
    primary: 'border-[#4DB3A8]',
  },
  hover: {
    bgPrimary: 'hover:bg-[#38827A]',
    textPrimary: 'hover:text-[#38827A]',
  },
} as const;
