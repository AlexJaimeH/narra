import React from 'react';

interface ErrorMessageProps {
  message: string;
  onRetry?: () => void;
}

export const ErrorMessage: React.FC<ErrorMessageProps> = ({ message, onRetry }) => {
  return (
    <div className="flex items-center justify-center min-h-screen px-4">
      <div className="max-w-md w-full bg-white rounded-lg shadow-lg p-8 text-center">
        <div className="text-5xl mb-4">⚠️</div>
        <h2 className="text-2xl font-bold text-text-primary mb-4">
          Algo salió mal
        </h2>
        <p className="text-text-secondary mb-6">{message}</p>
        {onRetry && (
          <button onClick={onRetry} className="btn-primary">
            Reintentar
          </button>
        )}
      </div>
    </div>
  );
};
