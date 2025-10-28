import React, { useEffect, useState } from 'react';
import { Header } from '../components/Header';
import { StoryCard } from '../components/StoryCard';
import { Loading } from '../components/Loading';
import { ErrorMessage } from '../components/ErrorMessage';
import { Story, PublicAuthorProfile } from '../types';
import { publicAccessService } from '../services/publicAccessService';
import { accessManager } from '../services/accessManager';
import { storyService } from '../services/storyService';

export const BlogHome: React.FC = () => {
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stories, setStories] = useState<Story[]>([]);
  const [author, setAuthor] = useState<PublicAuthorProfile | null>(null);
  const [subscriberName, setSubscriberName] = useState<string | null>(null);

  const loadBlog = async () => {
    setIsLoading(true);
    setError(null);

    try {
      // Parse URL parameters
      const urlParams = publicAccessService.parseSharePayloadFromUrl();

      if (!urlParams.authorId || !urlParams.subscriberId || !urlParams.token) {
        setError('El enlace parece incompleto. Por favor, solicita uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      // Register access and validate magic link
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

      // Store access locally
      accessManager.grantAccess(accessRecord);
      setSubscriberName(accessRecord.subscriberName || null);

      // Load author profile
      const profile = await storyService.getAuthorProfile(urlParams.authorId);
      setAuthor(profile);

      // Load stories
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
  }, []);

  if (isLoading) {
    return <Loading />;
  }

  if (error) {
    return <ErrorMessage message={error} onRetry={loadBlog} />;
  }

  return (
    <div className="min-h-screen bg-surface-light">
      <Header author={author || undefined} subscriberName={subscriberName || undefined} />

      <main className="max-w-4xl mx-auto px-4 py-8">
        {stories.length === 0 ? (
          <div className="text-center py-16">
            <p className="text-xl text-text-secondary">
              Aún no hay historias publicadas.
            </p>
            <p className="text-text-light mt-2">
              Vuelve pronto para descubrir nuevas historias.
            </p>
          </div>
        ) : (
          <>
            <div className="mb-6">
              <h2 className="text-3xl font-bold text-text-primary">
                Historias Publicadas
              </h2>
              <p className="text-text-secondary mt-2">
                {stories.length} {stories.length === 1 ? 'historia' : 'historias'} disponible{stories.length !== 1 ? 's' : ''}
              </p>
            </div>

            <div className="space-y-6">
              {stories.map(story => (
                <StoryCard key={story.id} story={story} />
              ))}
            </div>
          </>
        )}
      </main>

      <footer className="border-t border-gray-200 mt-16 py-8">
        <div className="max-w-4xl mx-auto px-4 text-center text-text-light text-sm">
          <p>Blog creado con Narra</p>
        </div>
      </footer>
    </div>
  );
};
