import React from 'react';
import { PublicAuthorProfile } from '../types';

interface HeaderProps {
  author?: PublicAuthorProfile;
  subscriberName?: string;
}

export const Header: React.FC<HeaderProps> = ({ author, subscriberName }) => {
  return (
    <header className="bg-white border-b border-gray-200">
      <div className="max-w-4xl mx-auto px-4 py-6">
        <div className="flex items-center gap-4">
          {author?.avatarUrl && (
            <img
              src={author.avatarUrl}
              alt={author.displayName}
              className="w-16 h-16 rounded-full object-cover"
            />
          )}
          {!author?.avatarUrl && (
            <div className="w-16 h-16 rounded-full bg-brand-primary flex items-center justify-center text-white text-2xl font-semibold">
              {(author?.displayName || 'A')[0].toUpperCase()}
            </div>
          )}

          <div className="flex-1">
            <h1 className="text-2xl font-bold text-text-primary">
              {author?.displayName || 'Mi Blog'}
            </h1>
            {author?.tagline && (
              <p className="text-text-secondary mt-1">{author.tagline}</p>
            )}
          </div>

          {subscriberName && (
            <div className="hidden md:block text-sm text-text-secondary">
              Bienvenido/a, <span className="font-medium text-text-primary">{subscriberName}</span>
            </div>
          )}
        </div>

        {author?.summary && (
          <p className="mt-4 text-text-secondary leading-relaxed">
            {author.summary}
          </p>
        )}
      </div>
    </header>
  );
};
