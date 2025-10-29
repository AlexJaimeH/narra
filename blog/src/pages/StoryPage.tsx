import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Loading } from '../components/Loading';
import { ErrorMessage } from '../components/ErrorMessage';
import { Story, PublicAuthorProfile } from '../types';
import { publicAccessService } from '../services/publicAccessService';
import { accessManager } from '../services/accessManager';
import { storyService } from '../services/storyService';
import { NarraColors } from '../styles/colors';

export const StoryPage: React.FC = () => {
  const { storyId } = useParams<{ storyId: string }>();
  const navigate = useNavigate();

  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [story, setStory] = useState<Story | null>(null);
  const [author, setAuthor] = useState<PublicAuthorProfile | null>(null);
  const [relatedStories, setRelatedStories] = useState<Story[]>([]);
  const [subscriberName, setSubscriberName] = useState<string | null>(null);
  const [authorId, setAuthorId] = useState<string | null>(null);

  const loadStory = async () => {
    if (!storyId) {
      setError('ID de historia no válido');
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      const urlParams = publicAccessService.parseSharePayloadFromUrl();
      console.log('[StoryPage] URL params:', urlParams);

      if (!urlParams.authorId || !urlParams.subscriberId || !urlParams.token) {
        console.error('[StoryPage] Missing URL params:', urlParams);
        setError('El enlace parece incompleto. Por favor, solicita uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      setAuthorId(urlParams.authorId);

      console.log('[StoryPage] Registering access...');
      const accessRecord = await publicAccessService.registerAccess({
        authorId: urlParams.authorId,
        subscriberId: urlParams.subscriberId,
        token: urlParams.token,
        storyId: storyId,
        source: urlParams.source || 'email',
        eventType: 'access_granted',
      });

      console.log('[StoryPage] Access record:', accessRecord);

      if (!accessRecord) {
        console.error('[StoryPage] No access record returned');
        setError('Este enlace ya no es válido. Por favor, pide uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      accessManager.grantAccess(accessRecord);
      setSubscriberName(accessRecord.subscriberName || null);

      console.log('[StoryPage] Loading story with ID:', storyId);

      const loadedStory = await storyService.getStory(storyId);
      console.log('[StoryPage] Loaded story:', loadedStory);

      if (!loadedStory) {
        console.error('[StoryPage] Failed to load story');
        setError('No se pudo cargar la historia. Por favor, intenta de nuevo.');
        setIsLoading(false);
        return;
      }
      setStory(loadedStory);

      const profile = await storyService.getAuthorProfile(loadedStory.userId);
      setAuthor(profile);

      const otherStories = await storyService.getLatestStories(loadedStory.userId, 4);
      setRelatedStories(otherStories.filter(s => s.id !== storyId));

      setIsLoading(false);
    } catch (err) {
      console.error('[StoryPage] Error loading story:', err);
      setError('Hubo un error al cargar la historia. Por favor, intenta de nuevo.');
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadStory();
  }, [storyId]);

  const formatDate = (dateString: string | null): string => {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  };

  const handleViewAllStories = () => {
    if (!authorId) return;
    const urlParams = publicAccessService.parseSharePayloadFromUrl();
    const queryString = new URLSearchParams({
      author: authorId,
      subscriber: urlParams.subscriberId || '',
      token: urlParams.token || '',
      ...(urlParams.source && { source: urlParams.source }),
    }).toString();
    navigate(`/blog/subscriber/${urlParams.subscriberId}?${queryString}`);
  };

  const handleUnsubscribe = () => {
    // TODO: Implementar desuscripción
    alert('Funcionalidad de desuscripción próximamente');
  };

  if (isLoading) {
    return <Loading />;
  }

  if (error) {
    return <ErrorMessage message={error} onRetry={loadStory} />;
  }

  if (!story) {
    return <ErrorMessage message="Historia no encontrada" />;
  }

  return (
    <div className="min-h-screen bg-surface-light">
      {/* Header con info del autor */}
      <header className="bg-white border-b border-gray-200 sticky top-0 z-10 shadow-sm">
        <div className="max-w-5xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              {author?.avatarUrl && (
                <img
                  src={author.avatarUrl}
                  alt={author.name}
                  className="w-12 h-12 rounded-full object-cover border-2"
                  style={{ borderColor: NarraColors.brand.primary }}
                />
              )}
              <div>
                <h2 className="text-xl font-bold text-text-primary">
                  {author?.displayName || 'Autor'}
                </h2>
                {author?.tagline && (
                  <p className="text-sm text-text-secondary">{author.tagline}</p>
                )}
              </div>
            </div>
            <button
              onClick={handleViewAllStories}
              className="px-4 py-2 rounded-lg font-medium transition-all"
              style={{
                backgroundColor: NarraColors.brand.primary,
                color: 'white',
              }}
              onMouseEnter={(e) => {
                e.currentTarget.style.backgroundColor = NarraColors.brand.primarySolid;
              }}
              onMouseLeave={(e) => {
                e.currentTarget.style.backgroundColor = NarraColors.brand.primary;
              }}
            >
              Ver todas las historias
            </button>
          </div>
        </div>
      </header>

      {/* Contenido principal */}
      <main className="max-w-4xl mx-auto px-4 py-12">
        {/* Historia */}
        <article className="bg-white rounded-2xl shadow-sm p-8 md:p-12 mb-8">
          <header className="mb-8 border-b border-gray-100 pb-8">
            <h1 className="text-4xl md:text-5xl font-bold text-text-primary mb-4 leading-tight">
              {story.title}
            </h1>

            <div className="flex flex-wrap items-center gap-4 text-text-secondary">
              {story.publishedAt && (
                <time className="text-sm flex items-center gap-1">
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  {formatDate(story.publishedAt)}
                </time>
              )}

              {story.tags && story.tags.length > 0 && (
                <div className="flex flex-wrap gap-2">
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
            </div>
          </header>

          {story.photos && story.photos.length > 0 && (
            <div className="mb-8 space-y-6">
              {story.photos.map(photo => (
                <figure key={photo.id} className="rounded-xl overflow-hidden">
                  <img
                    src={photo.photoUrl}
                    alt={photo.caption || story.title}
                    className="w-full rounded-xl shadow-lg"
                  />
                  {photo.caption && (
                    <figcaption className="mt-3 text-sm text-text-secondary text-center italic">
                      {photo.caption}
                    </figcaption>
                  )}
                </figure>
              ))}
            </div>
          )}

          <div
            className="prose prose-lg max-w-none"
            style={{ color: NarraColors.text.primary }}
            dangerouslySetInnerHTML={{ __html: story.content }}
          />

          <div className="mt-12 pt-8 border-t border-gray-200 flex items-center justify-between">
            <div className="text-sm text-text-secondary">
              {subscriberName && (
                <p>Hola {subscriberName}, esperamos que hayas disfrutado esta historia.</p>
              )}
            </div>
          </div>
        </article>

        {/* Historias relacionadas */}
        {relatedStories.length > 0 && (
          <section className="mb-8">
            <h2 className="text-2xl font-bold text-text-primary mb-6">
              Más historias de {author?.displayName || 'este autor'}
            </h2>
            <div className="grid gap-6 md:grid-cols-2">
              {relatedStories.map(relatedStory => (
                <a
                  key={relatedStory.id}
                  href={`/blog/story/${relatedStory.id}${window.location.search}`}
                  className="block bg-white rounded-xl shadow-sm p-6 hover:shadow-md transition-all"
                  style={{
                    borderTop: `3px solid ${NarraColors.brand.primary}`,
                  }}
                >
                  <h3 className="text-xl font-bold text-text-primary mb-2 line-clamp-2">
                    {relatedStory.title}
                  </h3>
                  {relatedStory.publishedAt && (
                    <p className="text-sm text-text-secondary mb-3">
                      {formatDate(relatedStory.publishedAt)}
                    </p>
                  )}
                  <div
                    className="text-text-secondary line-clamp-3 mb-3"
                    dangerouslySetInnerHTML={{
                      __html: relatedStory.content.substring(0, 150) + '...',
                    }}
                  />
                  <span
                    className="text-sm font-medium"
                    style={{ color: NarraColors.brand.primary }}
                  >
                    Leer historia →
                  </span>
                </a>
              ))}
            </div>
          </section>
        )}

        {/* Botón de desuscripción */}
        <div className="bg-white rounded-xl shadow-sm p-6 text-center">
          <p className="text-text-secondary mb-4">
            ¿No deseas recibir más historias de {author?.displayName || 'este autor'}?
          </p>
          <button
            onClick={handleUnsubscribe}
            className="text-sm text-text-light hover:text-text-secondary underline"
          >
            Desuscribirse
          </button>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-200 mt-16 py-8 bg-white">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <p className="text-text-secondary text-sm mb-2">
            Creado con{' '}
            <span style={{ color: NarraColors.brand.primary }} className="font-semibold">
              Narra
            </span>
          </p>
          <p className="text-text-light text-xs">
            Historias que perduran para siempre
          </p>
        </div>
      </footer>
    </div>
  );
};
