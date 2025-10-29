import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Loading } from '../components/Loading';
import { ErrorMessage } from '../components/ErrorMessage';
import { Story, PublicAuthorProfile } from '../types';
import { publicAccessService } from '../services/publicAccessService';
import { accessManager } from '../services/accessManager';
import { storyService } from '../services/storyService';
import { NarraColors } from '../styles/colors';

export const BlogHome: React.FC = () => {
  const { subscriberId } = useParams<{ subscriberId?: string }>();
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stories, setStories] = useState<Story[]>([]);
  const [author, setAuthor] = useState<PublicAuthorProfile | null>(null);
  const [subscriberName, setSubscriberName] = useState<string | null>(null);

  const loadBlog = async () => {
    setIsLoading(true);
    setError(null);

    try {
      const urlParams = publicAccessService.parseSharePayloadFromUrl();

      if (!urlParams.authorId || !urlParams.subscriberId || !urlParams.token) {
        setError('El enlace parece incompleto. Por favor, solicita uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      const accessRecord = await publicAccessService.registerAccess({
        authorId: urlParams.authorId,
        subscriberId: urlParams.subscriberId,
        token: urlParams.token,
        source: urlParams.source || 'invite',
        eventType: 'invite_opened',
      });

      if (!accessRecord) {
        setError('Este enlace ya no es válido. Por favor, pide uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      accessManager.grantAccess(accessRecord);
      setSubscriberName(accessRecord.subscriberName || null);

      const profile = await storyService.getAuthorProfile(urlParams.authorId);
      setAuthor(profile);

      const loadedStories = await storyService.getLatestStories(urlParams.authorId, 20);
      setStories(loadedStories);

      setIsLoading(false);
    } catch (err) {
      console.error('Error loading blog:', err);
      setError('Hubo un error al cargar el blog. Por favor, intenta de nuevo.');
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadBlog();
  }, [subscriberId]);

  const formatDate = (dateString: string | null): string => {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  const handleUnsubscribe = () => {
    alert('Funcionalidad de desuscripción próximamente');
  };

  if (isLoading) {
    return <Loading />;
  }

  if (error) {
    return <ErrorMessage message={error} onRetry={loadBlog} />;
  }

  return (
    <div className="min-h-screen bg-surface-light">
      {/* Header del blog */}
      <header
        className="relative overflow-hidden"
        style={{
          background: `linear-gradient(135deg, ${NarraColors.brand.primaryPale} 0%, ${NarraColors.brand.primaryLight} 100%)`,
        }}
      >
        <div className="max-w-4xl mx-auto px-4 py-16 text-center">
          <div className="mb-6">
            {author?.avatarUrl ? (
              <img
                src={author.avatarUrl}
                alt={author.name}
                className="w-24 h-24 rounded-full mx-auto object-cover border-4 border-white shadow-lg"
              />
            ) : (
              <div
                className="w-24 h-24 rounded-full mx-auto flex items-center justify-center text-white text-3xl font-bold shadow-lg"
                style={{ backgroundColor: NarraColors.brand.primary }}
              >
                {author?.displayName?.[0] || 'A'}
              </div>
            )}
          </div>

          <h1 className="text-4xl md:text-5xl font-bold mb-3" style={{ color: NarraColors.text.primary }}>
            Historias de {author?.displayName || 'Autor'}
          </h1>

          {author?.tagline && (
            <p className="text-xl mb-6" style={{ color: NarraColors.text.secondary }}>
              {author.tagline}
            </p>
          )}

          {subscriberName && (
            <p className="text-lg" style={{ color: NarraColors.text.secondary }}>
              Bienvenido, {subscriberName}
            </p>
          )}

          <div className="mt-8 inline-block px-6 py-2 rounded-full" style={{ backgroundColor: NarraColors.brand.primaryLight, color: NarraColors.brand.primarySolid }}>
            <span className="font-semibold">{stories.length}</span> {stories.length === 1 ? 'historia publicada' : 'historias publicadas'}
          </div>
        </div>
      </header>

      {/* Contenido principal */}
      <main className="max-w-4xl mx-auto px-4 py-12">
        {stories.length === 0 ? (
          <div className="text-center py-16 bg-white rounded-2xl shadow-sm">
            <svg
              className="w-16 h-16 mx-auto mb-4"
              style={{ color: NarraColors.brand.primary }}
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
            <p className="text-xl mb-2" style={{ color: NarraColors.text.secondary }}>
              Aún no hay historias publicadas.
            </p>
            <p style={{ color: NarraColors.text.light }}>
              Vuelve pronto para descubrir nuevas historias.
            </p>
          </div>
        ) : (
          <div className="space-y-8">
            {stories.map((story, index) => (
              <article
                key={story.id}
                className="bg-white rounded-2xl shadow-sm overflow-hidden hover:shadow-md transition-all"
              >
                <a href={`/blog/story/${story.id}${window.location.search}`} className="block">
                  <div className="p-8">
                    <div className="flex items-center gap-3 mb-4">
                      <div
                        className="w-10 h-10 rounded-full flex items-center justify-center text-white font-bold"
                        style={{ backgroundColor: NarraColors.brand.primary }}
                      >
                        {index + 1}
                      </div>
                      {story.publishedAt && (
                        <time className="text-sm flex items-center gap-1" style={{ color: NarraColors.text.secondary }}>
                          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                          </svg>
                          {formatDate(story.publishedAt)}
                        </time>
                      )}
                    </div>

                    <h2 className="text-3xl font-bold mb-4 leading-tight" style={{ color: NarraColors.text.primary }}>
                      {story.title}
                    </h2>

                    {story.photos && story.photos.length > 0 && (
                      <div className="mb-4 rounded-xl overflow-hidden">
                        <img
                          src={story.photos[0].photoUrl}
                          alt={story.title}
                          className="w-full h-64 object-cover"
                        />
                      </div>
                    )}

                    <div
                      className="prose prose-lg line-clamp-3 mb-4"
                      style={{ color: NarraColors.text.secondary }}
                      dangerouslySetInnerHTML={{ __html: story.content }}
                    />

                    {story.tags && story.tags.length > 0 && (
                      <div className="flex flex-wrap gap-2 mb-4">
                        {story.tags.map(tag => (
                          <span
                            key={tag.id}
                            className="px-3 py-1 text-sm rounded-full font-medium"
                            style={{
                              backgroundColor: NarraColors.brand.primaryLight,
                              color: NarraColors.brand.primarySolid,
                            }}
                          >
                            {tag.tag}
                          </span>
                        ))}
                      </div>
                    )}

                    <div
                      className="inline-flex items-center gap-2 text-sm font-semibold group"
                      style={{ color: NarraColors.brand.primary }}
                    >
                      Leer historia completa
                      <svg
                        className="w-4 h-4 group-hover:translate-x-1 transition-transform"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                      </svg>
                    </div>
                  </div>
                </a>
              </article>
            ))}
          </div>
        )}

        {/* Botón de desuscripción */}
        <div className="mt-12 bg-white rounded-xl shadow-sm p-6 text-center">
          <p className="mb-4" style={{ color: NarraColors.text.secondary }}>
            ¿No deseas recibir más historias de {author?.displayName || 'este autor'}?
          </p>
          <button
            onClick={handleUnsubscribe}
            className="text-sm underline"
            style={{ color: NarraColors.text.light }}
          >
            Desuscribirse
          </button>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-200 mt-16 py-8 bg-white">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <p className="text-sm mb-2" style={{ color: NarraColors.text.secondary }}>
            Creado con{' '}
            <span style={{ color: NarraColors.brand.primary }} className="font-semibold">
              Narra
            </span>
          </p>
          <p className="text-xs" style={{ color: NarraColors.text.light }}>
            Historias que perduran para siempre
          </p>
        </div>
      </footer>
    </div>
  );
};
