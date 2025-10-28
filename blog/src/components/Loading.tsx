import React from 'react';

export const Loading: React.FC = () => {
  return (
    <div className="flex items-center justify-center min-h-screen">
      <div className="text-center">
        <div className="inline-block w-12 h-12 border-4 border-gray-200 border-t-brand-primary rounded-full animate-spin"></div>
        <p className="mt-4 text-text-secondary">Cargando...</p>
      </div>
    </div>
  );
};
