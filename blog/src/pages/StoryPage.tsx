import React, { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { Header } from '../components/Header';
import { Comments } from '../components/Comments';
import { Loading } from '../components/Loading';
import { ErrorMessage } from '../components/ErrorMessage';
import { Story, PublicAuthorProfile, StoryFeedbackState } from '../types';
import { publicAccessService } from '../services/publicAccessService';
import { accessManager } from '../services/accessManager';
import { storyService } from '../services/storyService';
import { feedbackService } from '../services/feedbackService';

export const StoryPage: React.FC = () => {
  const { storyId } = useParams<{ storyId: string }>();

  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [story, setStory] = useState<Story | null>(null);
  const [author, setAuthor] = useState<PublicAuthorProfile | null>(null);
  const [feedback, setFeedback] = useState<StoryFeedbackState>({
    hasReacted: false,
    reactionCount: 0,
    commentCount: 0,
    comments: [],
  });
  const [subscriberName, setSubscriberName] = useState<string | null>(null);
  const [isSubmittingComment, setIsSubmittingComment] = useState(false);
  const [isTogglingReaction, setIsTogglingReaction] = useState(false);

  const loadStory = async () => {
    if (!storyId) {
      setError('ID de historia no válido');
      setIsLoading(false);
      return;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Parse URL parameters
      const urlParams = publicAccessService.parseSharePayloadFromUrl();
      console.log('[StoryPage] URL params:', urlParams);

      if (!urlParams.authorId || !urlParams.subscriberId || !urlParams.token) {
        console.error('[StoryPage] Missing URL params:', urlParams);
        setError('El enlace parece incompleto. Por favor, solicita uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      // Register access and validate magic link
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

      // Store access locally
      accessManager.grantAccess(accessRecord);
      setSubscriberName(accessRecord.subscriberName || null);

      console.log('[StoryPage] Loading story with ID:', storyId);
      console.log('[StoryPage] Supabase URL:', accessRecord.supabaseUrl);
      console.log('[StoryPage] Has anon key:', !!accessRecord.supabaseAnonKey);

      // Load story
      const loadedStory = await storyService.getStory(storyId);
      console.log('[StoryPage] Loaded story:', loadedStory);

      if (!loadedStory) {
        console.error('[StoryPage] Failed to load story');
        setError('No se pudo cargar la historia. Por favor, intenta de nuevo.');
        setIsLoading(false);
        return;
      }
      setStory(loadedStory);

      // Load author profile
      const profile = await storyService.getAuthorProfile(loadedStory.userId);
      setAuthor(profile);

      // Load feedback state
      const feedbackState = await feedbackService.fetchState({
        authorId: loadedStory.userId,
        storyId: storyId,
        subscriberId: accessRecord.subscriberId,
        token: accessRecord.accessToken,
        source: urlParams.source,
      });
      setFeedback(feedbackState);

      setIsLoading(false);
    } catch (err) {
      console.error('Error loading story:', err);
      setError('Hubo un error al cargar la historia. Por favor, intenta de nuevo.');
      setIsLoading(false);
    }
  };

  useEffect(() => {
    loadStory();
  }, [storyId]);

  const handleSubmitComment = async (content: string, parentCommentId?: string) => {
    if (!story) return;

    const accessRecord = accessManager.getAccess();
    if (!accessRecord) return;

    setIsSubmittingComment(true);

    try {
      const success = await feedbackService.submitComment({
        authorId: story.userId,
        storyId: story.id,
        subscriberId: accessRecord.subscriberId,
        token: accessRecord.accessToken,
        content,
        parentCommentId,
        source: accessRecord.source,
      });

      if (success) {
        // Reload feedback to get updated comments
        const feedbackState = await feedbackService.fetchState({
          authorId: story.userId,
          storyId: story.id,
          subscriberId: accessRecord.subscriberId,
          token: accessRecord.accessToken,
          source: accessRecord.source,
        });
        setFeedback(feedbackState);
      }
    } finally {
      setIsSubmittingComment(false);
    }
  };

  const handleToggleReaction = async () => {
    if (!story || isTogglingReaction) return;

    const accessRecord = accessManager.getAccess();
    if (!accessRecord) return;

    setIsTogglingReaction(true);

    try {
      const success = await feedbackService.toggleReaction({
        authorId: story.userId,
        storyId: story.id,
        subscriberId: accessRecord.subscriberId,
        token: accessRecord.accessToken,
        source: accessRecord.source,
      });

      if (success) {
        // Update local state optimistically
        setFeedback(prev => ({
          ...prev,
          hasReacted: !prev.hasReacted,
          reactionCount: prev.hasReacted ? prev.reactionCount - 1 : prev.reactionCount + 1,
        }));
      }
    } finally {
      setIsTogglingReaction(false);
    }
  };

  const formatDate = (dateString: string | null): string => {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
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
      <Header author={author || undefined} subscriberName={subscriberName || undefined} />

      <main className="max-w-4xl mx-auto px-4 py-8">
        <article className="bg-white rounded-xl shadow-sm p-8 md:p-12">
          <header className="mb-8">
            <h1 className="text-4xl md:text-5xl font-bold text-text-primary mb-4">
              {story.title}
            </h1>

            <div className="flex items-center gap-4 text-text-secondary">
              {story.publishedAt && (
                <time className="text-sm">
                  {formatDate(story.publishedAt)}
                </time>
              )}

              {story.tags && story.tags.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {story.tags.map(tag => (
                    <span
                      key={tag.id}
                      className="px-3 py-1 bg-brand-primary/10 text-brand-primary text-sm rounded-full"
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
                <figure key={photo.id}>
                  <img
                    src={photo.photoUrl}
                    alt={photo.caption || story.title}
                    className="w-full rounded-lg"
                  />
                  {photo.caption && (
                    <figcaption className="mt-2 text-sm text-text-secondary text-center italic">
                      {photo.caption}
                    </figcaption>
                  )}
                </figure>
              ))}
            </div>
          )}

          <div
            className="prose prose-lg max-w-none"
            dangerouslySetInnerHTML={{ __html: story.content }}
          />

          <div className="mt-12 pt-8 border-t border-gray-200">
            <button
              onClick={handleToggleReaction}
              disabled={isTogglingReaction}
              className={`flex items-center gap-2 px-6 py-3 rounded-lg font-medium transition-all ${
                feedback.hasReacted
                  ? 'bg-red-50 text-red-600 hover:bg-red-100'
                  : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
              }`}
            >
              <span className="text-xl">{feedback.hasReacted ? '♥' : '♡'}</span>
              <span>
                {feedback.hasReacted ? 'Me gusta' : 'Me gusta'}
                {feedback.reactionCount > 0 && ` (${feedback.reactionCount})`}
              </span>
            </button>
          </div>
        </article>

        <div className="mt-8 bg-white rounded-xl shadow-sm p-8 md:p-12">
          <Comments
            comments={feedback.comments}
            onSubmitComment={handleSubmitComment}
            isSubmitting={isSubmittingComment}
          />
        </div>
      </main>

      <footer className="border-t border-gray-200 mt-16 py-8">
        <div className="max-w-4xl mx-auto px-4 text-center text-text-light text-sm">
          <p>Blog creado con Narra</p>
        </div>
      </footer>
    </div>
  );
};
