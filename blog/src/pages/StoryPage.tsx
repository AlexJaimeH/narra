import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Loading } from '../components/Loading';
import { ErrorMessage } from '../components/ErrorMessage';
import { Story, PublicAuthorProfile, StoryFeedbackState, StoryFeedbackComment } from '../types';
import { publicAccessService } from '../services/publicAccessService';
import { accessManager } from '../services/accessManager';
import { storyService } from '../services/storyService';
import { feedbackService } from '../services/feedbackService';
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
  const [feedback, setFeedback] = useState<StoryFeedbackState>({
    hasReacted: false,
    reactionCount: 0,
    commentCount: 0,
    comments: [],
  });
  const [newComment, setNewComment] = useState('');
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [replyText, setReplyText] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
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
      const urlParams = publicAccessService.parseSharePayloadFromUrl();

      if (!urlParams.authorId || !urlParams.subscriberId || !urlParams.token) {
        setError('El enlace parece incompleto. Por favor, solicita uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      setAuthorId(urlParams.authorId);

      const accessRecord = await publicAccessService.registerAccess({
        authorId: urlParams.authorId,
        subscriberId: urlParams.subscriberId,
        token: urlParams.token,
        storyId: storyId,
        source: urlParams.source || 'email',
        eventType: 'access_granted',
      });

      if (!accessRecord) {
        setError('Este enlace ya no es válido. Por favor, pide uno nuevo al autor.');
        setIsLoading(false);
        return;
      }

      accessManager.grantAccess(accessRecord);
      setSubscriberName(accessRecord.subscriberName || null);

      const loadedStory = await storyService.getStory(storyId);

      if (!loadedStory) {
        setError('No se pudo cargar la historia. Por favor, intenta de nuevo.');
        setIsLoading(false);
        return;
      }
      setStory(loadedStory);

      const profile = await storyService.getAuthorProfile(loadedStory.userId);
      setAuthor(profile);

      const otherStories = await storyService.getLatestStories(loadedStory.userId, 4);
      setRelatedStories(otherStories.filter(s => s.id !== storyId));

      // Load feedback
      try {
        const feedbackState = await feedbackService.fetchState({
          authorId: loadedStory.userId,
          storyId: storyId,
          subscriberId: accessRecord.subscriberId,
          token: accessRecord.accessToken,
          source: accessRecord.source,
        });
        setFeedback(feedbackState);
      } catch (err) {
        console.error('Error loading feedback:', err);
      }

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

  const handleSubmitComment = async (content: string, parentId?: string) => {
    if (!story || !content.trim()) return;

    const accessRecord = accessManager.getAccess();
    if (!accessRecord) return;

    setIsSubmitting(true);

    try {
      const success = await feedbackService.submitComment({
        authorId: story.userId,
        storyId: story.id,
        subscriberId: accessRecord.subscriberId,
        token: accessRecord.accessToken,
        content: content.trim(),
        parentCommentId: parentId,
        source: accessRecord.source,
      });

      if (success) {
        const feedbackState = await feedbackService.fetchState({
          authorId: story.userId,
          storyId: story.id,
          subscriberId: accessRecord.subscriberId,
          token: accessRecord.accessToken,
          source: accessRecord.source,
        });
        setFeedback(feedbackState);
        setNewComment('');
        setReplyText('');
        setReplyingTo(null);
      }
    } finally {
      setIsSubmitting(false);
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
    alert('Funcionalidad de desuscripción próximamente');
  };

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message={error} onRetry={loadStory} />;
  if (!story) return <ErrorMessage message="Historia no encontrada" />;

  return (
    <div className="min-h-screen" style={{ background: `linear-gradient(to bottom, ${NarraColors.brand.primaryPale}, ${NarraColors.surface.white})` }}>
      {/* Header mejorado */}
      <header className="sticky top-0 z-50 backdrop-blur-md bg-white/90 border-b border-gray-100 shadow-sm">
        <div className="max-w-5xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              {author?.avatarUrl && (
                <div className="relative">
                  <img
                    src={author.avatarUrl}
                    alt={author.displayName}
                    className="w-14 h-14 rounded-full object-cover ring-4 ring-white shadow-lg"
                  />
                  <div className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full flex items-center justify-center shadow-md" style={{ backgroundColor: NarraColors.brand.primary }}>
                    <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                </div>
              )}
              <div>
                <h2 className="text-xl font-bold" style={{ color: NarraColors.text.primary }}>
                  {author?.displayName}
                </h2>
                {author?.tagline && (
                  <p className="text-sm" style={{ color: NarraColors.text.secondary }}>{author.tagline}</p>
                )}
              </div>
            </div>
            <button
              onClick={handleViewAllStories}
              className="px-5 py-2.5 rounded-xl font-semibold transition-all transform hover:scale-105 active:scale-95 shadow-md hover:shadow-lg"
              style={{
                backgroundColor: NarraColors.brand.primary,
                color: 'white',
              }}
            >
              Ver todo
            </button>
          </div>
        </div>
      </header>

      {/* Contenido principal */}
      <main className="max-w-4xl mx-auto px-4 py-8">
        {/* Historia */}
        <article className="bg-white rounded-3xl shadow-xl p-8 md:p-12 mb-8 transform transition-all hover:shadow-2xl">
          <header className="mb-8">
            <h1 className="text-4xl md:text-5xl font-bold mb-6 leading-tight bg-gradient-to-r from-gray-900 to-gray-600 bg-clip-text text-transparent">
              {story.title}
            </h1>

            <div className="flex flex-wrap items-center gap-4">
              {story.publishedAt && (
                <time className="flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium" style={{ backgroundColor: NarraColors.brand.primaryLight, color: NarraColors.brand.primarySolid }}>
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
                      className="px-4 py-2 text-sm rounded-full font-semibold shadow-sm"
                      style={{
                        backgroundColor: NarraColors.brand.primaryLight,
                        color: NarraColors.brand.primarySolid,
                      }}
                    >
                      #{tag.tag}
                    </span>
                  ))}
                </div>
              )}
            </div>
          </header>

          {story.photos && story.photos.length > 0 && (
            <div className="mb-8 space-y-6">
              {story.photos.map((photo, index) => (
                <figure key={photo.id} className="group">
                  <div className="rounded-2xl overflow-hidden shadow-xl transform transition-all hover:scale-[1.02]">
                    <img
                      src={photo.photoUrl}
                      alt={photo.caption || story.title}
                      className="w-full"
                    />
                  </div>
                  {photo.caption && (
                    <figcaption className="mt-4 text-center text-sm italic px-4" style={{ color: NarraColors.text.secondary }}>
                      {photo.caption}
                    </figcaption>
                  )}
                </figure>
              ))}
            </div>
          )}

          <div
            className="prose prose-lg max-w-none leading-relaxed"
            style={{ color: NarraColors.text.primary }}
            dangerouslySetInnerHTML={{ __html: story.content }}
          />

          {/* Reacciones */}
          <div className="mt-12 pt-8 border-t border-gray-100">
            <div className="flex items-center gap-4">
              <button
                onClick={handleToggleReaction}
                disabled={isTogglingReaction}
                className="group flex items-center gap-3 px-6 py-3 rounded-2xl font-semibold transition-all transform hover:scale-105 active:scale-95 shadow-md hover:shadow-lg"
                style={{
                  backgroundColor: feedback.hasReacted ? NarraColors.interactive.heartLight : NarraColors.brand.primaryLight,
                  color: feedback.hasReacted ? NarraColors.interactive.heart : NarraColors.brand.primarySolid,
                }}
              >
                <svg className={`w-6 h-6 transition-transform ${feedback.hasReacted ? 'scale-110' : 'group-hover:scale-110'}`} fill={feedback.hasReacted ? 'currentColor' : 'none'} viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </svg>
                <span>{feedback.hasReacted ? 'Te gusta' : 'Me gusta'}</span>
                {feedback.reactionCount > 0 && (
                  <span className="px-2.5 py-1 rounded-full text-sm font-bold" style={{ backgroundColor: 'white' }}>
                    {feedback.reactionCount}
                  </span>
                )}
              </button>

              <div className="flex items-center gap-2 px-4 py-2 rounded-full" style={{ backgroundColor: NarraColors.brand.primaryPale, color: NarraColors.text.secondary }}>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
                </svg>
                <span className="font-semibold">{feedback.commentCount} {feedback.commentCount === 1 ? 'comentario' : 'comentarios'}</span>
              </div>
            </div>
          </div>
        </article>

        {/* Comentarios */}
        <section className="bg-white rounded-3xl shadow-xl p-8 mb-8">
          <h2 className="text-2xl font-bold mb-6" style={{ color: NarraColors.text.primary }}>
            Comentarios ({feedback.commentCount})
          </h2>

          {/* Nuevo comentario */}
          <div className="mb-8">
            <textarea
              value={newComment}
              onChange={(e) => setNewComment(e.target.value)}
              placeholder={`${subscriberName ? subscriberName + ', d' : 'D'}éjanos saber qué te pareció esta historia...`}
              className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none focus:ring-2 transition-all"
              style={{
                borderColor: NarraColors.border.light,
                focusRing: NarraColors.brand.primary,
              }}
              rows={3}
            />
            <div className="flex justify-end mt-3">
              <button
                onClick={() => handleSubmitComment(newComment)}
                disabled={isSubmitting || !newComment.trim()}
                className="px-6 py-2.5 rounded-xl font-semibold transition-all transform hover:scale-105 active:scale-95 shadow-md disabled:opacity-50 disabled:cursor-not-allowed"
                style={{
                  backgroundColor: NarraColors.brand.primary,
                  color: 'white',
                }}
              >
                {isSubmitting ? 'Enviando...' : 'Comentar'}
              </button>
            </div>
          </div>

          {/* Lista de comentarios */}
          <div className="space-y-6">
            {feedback.comments.map(comment => (
              <CommentThread
                key={comment.id}
                comment={comment}
                onReply={(parentId, content) => handleSubmitComment(content, parentId)}
                isSubmitting={isSubmitting}
                replyingTo={replyingTo}
                setReplyingTo={setReplyingTo}
                replyText={replyText}
                setReplyText={setReplyText}
              />
            ))}

            {feedback.comments.length === 0 && (
              <div className="text-center py-12">
                <svg className="w-16 h-16 mx-auto mb-4 opacity-50" style={{ color: NarraColors.brand.primary }} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                <p style={{ color: NarraColors.text.secondary }}>Sé el primero en comentar esta historia</p>
              </div>
            )}
          </div>
        </section>

        {/* Historias relacionadas mejoradas */}
        {relatedStories.length > 0 && (
          <section className="mb-8">
            <h2 className="text-3xl font-bold mb-6" style={{ color: NarraColors.text.primary }}>
              Más historias de {author?.displayName}
            </h2>
            <div className="grid gap-6 md:grid-cols-2">
              {relatedStories.map(relatedStory => (
                <RelatedStoryCard key={relatedStory.id} story={relatedStory} formatDate={formatDate} />
              ))}
            </div>
          </section>
        )}

        {/* Desuscripción */}
        <div className="bg-white/50 backdrop-blur rounded-2xl p-6 text-center border border-gray-100">
          <p className="mb-4" style={{ color: NarraColors.text.secondary }}>
            ¿No deseas recibir más historias de {author?.displayName}?
          </p>
          <button
            onClick={handleUnsubscribe}
            className="text-sm underline hover:no-underline transition-all"
            style={{ color: NarraColors.text.light }}
          >
            Desuscribirse
          </button>
        </div>
      </main>

      {/* Footer */}
      <footer className="border-t border-gray-100 mt-16 py-8 bg-white/80 backdrop-blur">
        <div className="max-w-4xl mx-auto px-4 text-center">
          <p className="text-sm mb-2" style={{ color: NarraColors.text.secondary }}>
            Creado con{' '}
            <span style={{ color: NarraColors.brand.primary }} className="font-bold">
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

// Componente de thread de comentarios
const CommentThread: React.FC<{
  comment: StoryFeedbackComment;
  onReply: (parentId: string, content: string) => void;
  isSubmitting: boolean;
  replyingTo: string | null;
  setReplyingTo: (id: string | null) => void;
  replyText: string;
  setReplyText: (text: string) => void;
}> = ({ comment, onReply, isSubmitting, replyingTo, setReplyingTo, replyText, setReplyText }) => {
  const formatDate = (dateString: string): string => {
    const date = new Date(dateString);
    return date.toLocaleDateString('es-MX', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  };

  return (
    <div className="group">
      <div className="flex gap-4">
        <div className="flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center font-bold text-white shadow-md" style={{ backgroundColor: NarraColors.brand.primary }}>
          {comment.subscriberName?.[0]?.toUpperCase() || 'A'}
        </div>
        <div className="flex-1">
          <div className="bg-gray-50 rounded-2xl p-4 group-hover:bg-gray-100 transition-colors">
            <div className="flex items-center gap-2 mb-2">
              <span className="font-semibold" style={{ color: NarraColors.text.primary }}>
                {comment.subscriberName || 'Lector'}
              </span>
              <span className="text-xs" style={{ color: NarraColors.text.light }}>
                {formatDate(comment.createdAt)}
              </span>
            </div>
            <p style={{ color: NarraColors.text.secondary }}>{comment.content}</p>
          </div>
          <button
            onClick={() => setReplyingTo(replyingTo === comment.id ? null : comment.id)}
            className="text-sm font-medium mt-2 hover:underline"
            style={{ color: NarraColors.brand.primary }}
          >
            Responder
          </button>

          {replyingTo === comment.id && (
            <div className="mt-4">
              <textarea
                value={replyText}
                onChange={(e) => setReplyText(e.target.value)}
                placeholder="Escribe tu respuesta..."
                className="w-full px-4 py-3 rounded-xl border-2 focus:outline-none transition-all"
                style={{ borderColor: NarraColors.border.light }}
                rows={2}
              />
              <div className="flex gap-2 mt-2">
                <button
                  onClick={() => {
                    onReply(comment.id, replyText);
                  }}
                  disabled={isSubmitting || !replyText.trim()}
                  className="px-4 py-2 rounded-xl text-sm font-semibold transition-all disabled:opacity-50"
                  style={{
                    backgroundColor: NarraColors.brand.primary,
                    color: 'white',
                  }}
                >
                  Responder
                </button>
                <button
                  onClick={() => {
                    setReplyingTo(null);
                    setReplyText('');
                  }}
                  className="px-4 py-2 rounded-xl text-sm font-semibold"
                  style={{ color: NarraColors.text.secondary }}
                >
                  Cancelar
                </button>
              </div>
            </div>
          )}

          {comment.replies && comment.replies.length > 0 && (
            <div className="mt-4 ml-6 space-y-4 border-l-2 pl-4" style={{ borderColor: NarraColors.brand.primaryLight }}>
              {comment.replies.map(reply => (
                <CommentThread
                  key={reply.id}
                  comment={reply}
                  onReply={onReply}
                  isSubmitting={isSubmitting}
                  replyingTo={replyingTo}
                  setReplyingTo={setReplyingTo}
                  replyText={replyText}
                  setReplyText={setReplyText}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// Componente de card de historia relacionada
const RelatedStoryCard: React.FC<{
  story: Story;
  formatDate: (date: string | null) => string;
}> = ({ story, formatDate }) => {
  return (
    <a
      href={`/blog/story/${story.id}${window.location.search}`}
      className="block bg-white rounded-2xl shadow-lg overflow-hidden hover:shadow-2xl transition-all transform hover:-translate-y-1"
    >
      {story.photos && story.photos.length > 0 && (
        <div className="h-48 overflow-hidden">
          <img
            src={story.photos[0].photoUrl}
            alt={story.title}
            className="w-full h-full object-cover transform hover:scale-110 transition-transform duration-500"
          />
        </div>
      )}
      <div className="p-6" style={{ borderTop: `4px solid ${NarraColors.brand.primary}` }}>
        {story.publishedAt && (
          <p className="text-xs font-medium mb-2" style={{ color: NarraColors.text.secondary }}>
            {formatDate(story.publishedAt)}
          </p>
        )}
        <h3 className="text-xl font-bold mb-3 line-clamp-2" style={{ color: NarraColors.text.primary }}>
          {story.title}
        </h3>
        {story.tags && story.tags.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-3">
            {story.tags.slice(0, 2).map(tag => (
              <span
                key={tag.id}
                className="px-2 py-1 text-xs rounded-full font-semibold"
                style={{
                  backgroundColor: NarraColors.brand.primaryLight,
                  color: NarraColors.brand.primarySolid,
                }}
              >
                #{tag.tag}
              </span>
            ))}
          </div>
        )}
        <div
          className="text-sm font-semibold flex items-center gap-1"
          style={{ color: NarraColors.brand.primary }}
        >
          Leer historia
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </div>
      </div>
    </a>
  );
};
