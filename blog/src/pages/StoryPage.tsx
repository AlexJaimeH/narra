import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, useInView } from 'framer-motion';
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
  const [showUnsubscribeConfirm, setShowUnsubscribeConfirm] = useState(false);
  const [showUnsubscribeSuccess, setShowUnsubscribeSuccess] = useState(false);
  const [isUnsubscribing, setIsUnsubscribing] = useState(false);
  const [readingProgress, setReadingProgress] = useState(0);

  // Reading progress tracking
  useEffect(() => {
    const handleScroll = () => {
      const windowHeight = window.innerHeight;
      const documentHeight = document.documentElement.scrollHeight;
      const scrollTop = window.scrollY;
      const trackLength = documentHeight - windowHeight;
      const progress = (scrollTop / trackLength) * 100;
      setReadingProgress(Math.min(progress, 100));
    };

    window.addEventListener('scroll', handleScroll);
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

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
        // Silently fail - feedback is optional
      }

      setIsLoading(false);
    } catch (err) {
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
        active: !feedback.hasReacted,
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

  // Parse date string correctly to avoid timezone issues
  const parseDate = (dateString: string): Date => {
    const [year, month, day] = dateString.split('-').map(Number);
    return new Date(year, month - 1, day); // month is 0-indexed
  };

  const formatStoryDate = (story: Story): string => {
    const dateToUse = story.startDate || story.storyDate;
    if (!dateToUse) return '';

    const startDate = parseDate(dateToUse);
    const precision = story.datesPrecision || 'day';

    let formattedStart = '';
    if (precision === 'year') {
      formattedStart = startDate.getFullYear().toString();
    } else if (precision === 'month') {
      formattedStart = startDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long' });
    } else {
      formattedStart = startDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long', day: 'numeric' });
    }

    if (story.endDate) {
      const endDate = parseDate(story.endDate);
      let formattedEnd = '';
      if (precision === 'year') {
        formattedEnd = endDate.getFullYear().toString();
      } else if (precision === 'month') {
        formattedEnd = endDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long' });
      } else {
        formattedEnd = endDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long', day: 'numeric' });
      }
      return `${formattedStart} - ${formattedEnd}`;
    }

    return formattedStart;
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
    setShowUnsubscribeConfirm(true);
  };

  const confirmUnsubscribe = async () => {
    const accessRecord = accessManager.getAccess();
    if (!accessRecord) return;

    setIsUnsubscribing(true);

    try {
      const response = await publicAccessService.registerAccess({
        authorId: accessRecord.authorId,
        subscriberId: accessRecord.subscriberId,
        token: accessRecord.accessToken,
        source: accessRecord.source,
        eventType: 'unsubscribe' as any,
      });

      setIsUnsubscribing(false);
      setShowUnsubscribeConfirm(false);

      if (response === null) {
        // Successfully unsubscribed
        setShowUnsubscribeSuccess(true);
        accessManager.revokeAccess();
      }
    } catch (error) {
      setIsUnsubscribing(false);
      alert('Hubo un error al desuscribirte. Por favor, intenta de nuevo.');
    }
  };

  const handleCloseSuccessDialog = () => {
    setShowUnsubscribeSuccess(false);
    navigate('/');
  };

  // Process story content to replace image placeholders with actual images
  const processStoryContent = (content: string, photos: any[] | undefined, storyTitle: string): string => {
    // First, convert plain text line breaks to HTML
    // Replace double line breaks with paragraph breaks
    let processedContent = content
      .split('\n\n')
      .map(paragraph => paragraph.trim())
      .filter(paragraph => paragraph.length > 0)
      .map(paragraph => {
        // Within each paragraph, replace single line breaks with <br>
        const paragraphWithBreaks = paragraph.split('\n').join('<br>');
        return `<p>${paragraphWithBreaks}</p>`;
      })
      .join('\n');

    // Then, replace image placeholders with actual images
    if (photos && photos.length > 0) {
      photos.forEach((photo, index) => {
        const placeholder = `[img_${index + 1}]`;
        const imageHtml = `
          <figure class="my-8">
            <div class="rounded-2xl overflow-hidden shadow-xl transform transition-all hover:scale-[1.02]">
              <img
                src="${photo.photoUrl}"
                alt="${photo.caption || storyTitle}"
                class="w-full"
              />
            </div>
            ${photo.caption ? `<figcaption class="mt-4 text-center text-sm italic" style="color: #6B7280;">${photo.caption}</figcaption>` : ''}
          </figure>
        `;

        // Replace all occurrences of the placeholder
        processedContent = processedContent.split(placeholder).join(imageHtml);
      });
    }

    return processedContent;
  };

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message={error} onRetry={loadStory} />;
  if (!story) return <ErrorMessage message="Historia no encontrada" />;

  return (
    <div className="min-h-screen smooth-scroll" style={{ background: `linear-gradient(to bottom, ${NarraColors.brand.primaryPale}, ${NarraColors.surface.white})` }}>
      {/* Reading progress bar */}
      <div
        className="reading-progress"
        style={{ width: `${readingProgress}%` }}
      />

      {/* Header mejorado */}
      <header className="sticky top-0 z-40 glass shadow-sm animate-fade-in">
        <div className="max-w-5xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4 animate-slide-in-left">
              {author?.avatarUrl && (
                <div className="relative">
                  <img
                    src={author.avatarUrl}
                    alt={author.displayName}
                    className="w-14 h-14 rounded-full object-cover ring-4 ring-white shadow-lg transform hover:scale-105 transition-transform"
                  />
                  <div className="absolute -bottom-1 -right-1 w-5 h-5 rounded-full flex items-center justify-center shadow-md animate-float" style={{ backgroundColor: NarraColors.brand.primary }}>
                    <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                    </svg>
                  </div>
                </div>
              )}
              <div>
                <h2 className="text-xl font-bold" style={{ color: NarraColors.text.primary, fontFamily: "'Playfair Display', serif" }}>
                  {author?.displayName}
                </h2>
                {author?.tagline && (
                  <p className="text-sm" style={{ color: NarraColors.text.secondary }}>{author.tagline}</p>
                )}
              </div>
            </div>
            <button
              onClick={handleViewAllStories}
              className="px-5 py-2.5 rounded-xl font-semibold transition-all transform hover:scale-105 active:scale-95 shadow-md hover:shadow-lg animate-slide-in-right"
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
        <motion.article
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, ease: [0.21, 0.47, 0.32, 0.98] }}
          className="bg-white rounded-3xl shadow-soft-hover p-8 md:p-12 mb-8"
        >
          <header className="mb-10">
            <motion.h1
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.2 }}
              className="text-4xl md:text-6xl font-bold mb-6 leading-tight"
              style={{
                fontFamily: "'Playfair Display', serif",
                background: 'linear-gradient(135deg, #1F2937 0%, #4B5563 50%, #1F2937 100%)',
                WebkitBackgroundClip: 'text',
                backgroundClip: 'text',
                WebkitTextFillColor: 'transparent',
                letterSpacing: '-0.02em'
              }}
            >
              {story.title}
            </motion.h1>

            <div className="flex flex-col gap-3 animate-fade-in stagger-1">
              <div className="flex flex-wrap items-center gap-3">
                {formatStoryDate(story) && (
                  <div className="flex items-center gap-2 px-4 py-2 rounded-full text-sm font-semibold shadow-sm transform hover:scale-105 transition-all" style={{ backgroundColor: NarraColors.brand.primaryLight, color: NarraColors.brand.primarySolid }}>
                    <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    <time>{formatStoryDate(story)}</time>
                  </div>
                )}

                {story.tags && story.tags.length > 0 && (
                  <div className="flex flex-wrap gap-2">
                    {story.tags.map((tag, idx) => (
                      <span
                        key={tag.id}
                        className="px-4 py-2 text-sm rounded-full font-semibold shadow-sm transform hover:scale-105 transition-all"
                        style={{
                          backgroundColor: NarraColors.brand.primaryLight,
                          color: NarraColors.brand.primarySolid,
                          transitionDelay: `${idx * 50}ms`
                        }}
                      >
                        #{tag.name || tag.tag}
                      </span>
                    ))}
                  </div>
                )}
              </div>
              {story.publishedAt && (
                <p className="text-sm italic flex items-center gap-2" style={{ color: NarraColors.text.light }}>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  Publicado el {formatDate(story.publishedAt)}
                </p>
              )}
            </div>
          </header>

          <div
            className="prose prose-lg max-w-none leading-relaxed animate-fade-in stagger-2"
            style={{
              color: NarraColors.text.primary,
              fontFamily: "'Inter', sans-serif",
              fontSize: '1.125rem',
              lineHeight: '1.9'
            }}
            dangerouslySetInnerHTML={{ __html: processStoryContent(story.content, story.photos, story.title) }}
          />

          {/* Reacciones */}
          <div className="mt-12 pt-8 border-t border-gray-100 animate-fade-in stagger-3">
            <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
              <motion.button
                onClick={handleToggleReaction}
                disabled={isTogglingReaction}
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                animate={feedback.hasReacted ? {
                  scale: [1, 1.2, 1],
                  rotate: [0, 10, -10, 0]
                } : {}}
                transition={{ duration: 0.5 }}
                className="group flex items-center justify-center gap-2 sm:gap-3 px-4 sm:px-6 py-3 rounded-2xl font-semibold shadow-md hover:shadow-xl"
                style={{
                  backgroundColor: feedback.hasReacted ? NarraColors.interactive.heartLight : NarraColors.brand.primaryLight,
                  color: feedback.hasReacted ? NarraColors.interactive.heart : NarraColors.brand.primarySolid,
                }}
              >
                <motion.svg
                  animate={feedback.hasReacted ? {
                    scale: [1, 1.3, 1],
                  } : {}}
                  transition={{ duration: 0.3, repeat: feedback.hasReacted ? Infinity : 0, repeatDelay: 1 }}
                  className={`w-5 sm:w-6 h-5 sm:h-6 flex-shrink-0`}
                  fill={feedback.hasReacted ? 'currentColor' : 'none'}
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
                </motion.svg>
                <span className="text-sm sm:text-base">{feedback.hasReacted ? 'Te gusta' : 'Me gusta'}</span>
                {feedback.reactionCount > 0 && (
                  <motion.span
                    initial={{ scale: 0 }}
                    animate={{ scale: 1 }}
                    className="px-2 sm:px-2.5 py-1 rounded-full text-xs sm:text-sm font-bold"
                    style={{ backgroundColor: 'white' }}
                  >
                    {feedback.reactionCount}
                  </motion.span>
                )}
              </motion.button>

              <div className="flex items-center justify-center gap-2 px-4 py-2 rounded-full transform hover:scale-105 transition-all" style={{ backgroundColor: NarraColors.brand.primaryPale, color: NarraColors.text.secondary }}>
                <svg className="w-4 sm:w-5 h-4 sm:h-5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
                </svg>
                <span className="font-semibold text-sm sm:text-base">{feedback.commentCount} {feedback.commentCount === 1 ? 'comentario' : 'comentarios'}</span>
              </div>
            </div>
          </div>
        </motion.article>

        {/* Comentarios */}
        <motion.section
          initial={{ opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.3, ease: [0.21, 0.47, 0.32, 0.98] }}
          className="bg-white rounded-3xl shadow-soft-hover p-8 mb-8"
        >
          <h2 className="text-2xl font-bold mb-6" style={{ color: NarraColors.text.primary, fontFamily: "'Playfair Display', serif" }}>
            Comentarios ({feedback.commentCount})
          </h2>

          {/* Nuevo comentario */}
          <div className="mb-8">
            <textarea
              value={newComment}
              onChange={(e) => setNewComment(e.target.value)}
              placeholder={`${subscriberName ? subscriberName + ', d' : 'D'}éjanos saber qué te pareció esta historia...`}
              className="w-full px-5 py-4 rounded-xl border-2 focus:outline-none focus:ring-2 transition-all duration-300 shadow-sm focus:shadow-md"
              style={{
                borderColor: NarraColors.border.light,
                fontFamily: "'Inter', sans-serif"
              }}
              rows={4}
            />
            <div className="flex justify-end mt-3">
              <button
                onClick={() => handleSubmitComment(newComment)}
                disabled={isSubmitting || !newComment.trim()}
                className="px-6 py-3 rounded-xl font-semibold transition-all duration-300 transform hover:scale-105 active:scale-95 shadow-md hover:shadow-lg disabled:opacity-50 disabled:cursor-not-allowed disabled:transform-none"
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
                authorId={authorId}
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
        </motion.section>

        {/* Historias relacionadas mejoradas */}
        {relatedStories.length > 0 && (
          <section className="mb-8 animate-fade-in">
            <h2 className="text-3xl font-bold mb-6" style={{ color: NarraColors.text.primary, fontFamily: "'Playfair Display', serif" }}>
              Más historias de {author?.displayName}
            </h2>
            <div className="grid gap-6 md:grid-cols-2">
              {relatedStories.map((relatedStory, idx) => (
                <div key={relatedStory.id} className="animate-fade-in" style={{ animationDelay: `${idx * 0.1}s` }}>
                  <RelatedStoryCard story={relatedStory} formatDate={formatDate} />
                </div>
              ))}
            </div>
          </section>
        )}

        {/* Desuscripción - Solo mostrar si no es el autor */}
        {!accessManager.getAccess()?.isAuthor && (
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
        )}
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

      {/* Diálogo de confirmación de desuscripción */}
      {showUnsubscribeConfirm && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-8 max-w-md w-full shadow-2xl">
            <h3 className="text-2xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
              ¿Estás seguro/a?
            </h3>
            <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
              Si te desuscribes, ya no recibirás más historias de {author?.displayName}.
              Tus enlaces mágicos dejarán de funcionar.
            </p>
            <div className="flex gap-3">
              <button
                onClick={() => setShowUnsubscribeConfirm(false)}
                disabled={isUnsubscribing}
                className="flex-1 px-6 py-3 rounded-xl font-medium transition-all border-2"
                style={{
                  borderColor: NarraColors.brand.primary,
                  color: NarraColors.brand.primary,
                }}
              >
                Cancelar
              </button>
              <button
                onClick={confirmUnsubscribe}
                disabled={isUnsubscribing}
                className="flex-1 px-6 py-3 rounded-xl font-medium transition-all text-white"
                style={{
                  backgroundColor: isUnsubscribing ? NarraColors.text.light : NarraColors.brand.primary,
                }}
              >
                {isUnsubscribing ? 'Procesando...' : 'Sí, desuscribirme'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Diálogo de éxito de desuscripción */}
      {showUnsubscribeSuccess && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl p-8 max-w-md w-full shadow-2xl">
            <h3 className="text-2xl font-bold mb-4" style={{ color: NarraColors.text.primary }}>
              Te has desuscrito
            </h3>
            <p className="mb-6" style={{ color: NarraColors.text.secondary }}>
              Ya no recibirás más historias de {author?.displayName}.
              {' '}Si deseas volver a suscribirte en el futuro, por favor contacta directamente al autor.
            </p>
            <button
              onClick={handleCloseSuccessDialog}
              className="w-full px-6 py-3 rounded-xl font-medium transition-all text-white"
              style={{ backgroundColor: NarraColors.brand.primary }}
            >
              Entendido
            </button>
          </div>
        </div>
      )}
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
  authorId: string | null;
}> = ({ comment, onReply, isSubmitting, replyingTo, setReplyingTo, replyText, setReplyText, authorId }) => {
  const formatRelativeDate = (dateString: string): string => {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) {
      return 'Hace un momento';
    } else if (diffInSeconds < 3600) {
      const minutes = Math.floor(diffInSeconds / 60);
      return `Hace ${minutes} ${minutes === 1 ? 'minuto' : 'minutos'}`;
    } else if (diffInSeconds < 86400) {
      const hours = Math.floor(diffInSeconds / 3600);
      return `Hace ${hours} ${hours === 1 ? 'hora' : 'horas'}`;
    } else if (diffInSeconds < 604800) {
      const days = Math.floor(diffInSeconds / 86400);
      return `Hace ${days} ${days === 1 ? 'día' : 'días'}`;
    } else {
      return date.toLocaleDateString('es-MX', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    }
  };

  // Parse the name to check if it's the author
  const parseNameAndRole = (name: string) => {
    if (name.endsWith(' - Autor')) {
      const authorName = name.replace(' - Autor', '');
      return { name: authorName, isAuthor: true };
    }
    return { name, isAuthor: false };
  };

  const { name, isAuthor } = parseNameAndRole(comment.subscriberName || 'Suscriptor');

  return (
    <div className="group animate-fade-in">
      <div className="flex gap-4">
        <div className="flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center font-bold text-white shadow-md transform group-hover:scale-110 transition-transform" style={{ backgroundColor: NarraColors.brand.primary }}>
          {name[0]?.toUpperCase() || 'S'}
        </div>
        <div className="flex-1">
          <div className="bg-gray-50 rounded-2xl p-4 group-hover:bg-gray-100 transition-all duration-300 shadow-sm group-hover:shadow-md">
            <div className="flex items-center gap-2 mb-2 flex-wrap">
              <span className="font-semibold" style={{ color: NarraColors.text.primary }}>
                {name}
              </span>
              {isAuthor && (
                <span className="px-2 py-0.5 text-xs font-bold rounded transform group-hover:scale-105 transition-transform" style={{ backgroundColor: NarraColors.brand.primary, color: 'white' }}>
                  Autor
                </span>
              )}
              <span className="text-xs" style={{ color: NarraColors.text.light }}>
                {formatRelativeDate(comment.createdAt)}
              </span>
            </div>
            <p style={{ color: NarraColors.text.secondary, lineHeight: '1.6' }}>{comment.content}</p>
          </div>
          <button
            onClick={() => setReplyingTo(replyingTo === comment.id ? null : comment.id)}
            className="text-sm font-medium mt-2 hover:underline transition-all transform hover:translate-x-1"
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
                  authorId={authorId}
                />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

// Componente de card de historia relacionada con animaciones
const RelatedStoryCard: React.FC<{
  story: Story;
  formatDate: (date: string | null) => string;
}> = ({ story, formatDate }) => {
  const ref = React.useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-50px" });

  // Parse date string correctly to avoid timezone issues
  const parseDate = (dateString: string): Date => {
    const [year, month, day] = dateString.split('-').map(Number);
    return new Date(year, month - 1, day); // month is 0-indexed
  };

  const formatStoryDate = (story: Story): string => {
    const dateToUse = story.startDate || story.storyDate;
    if (!dateToUse) return '';

    const startDate = parseDate(dateToUse);
    const precision = story.datesPrecision || 'day';

    let formattedStart = '';
    if (precision === 'year') {
      formattedStart = startDate.getFullYear().toString();
    } else if (precision === 'month') {
      formattedStart = startDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long' });
    } else {
      formattedStart = startDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long', day: 'numeric' });
    }

    if (story.endDate) {
      const endDate = parseDate(story.endDate);
      let formattedEnd = '';
      if (precision === 'year') {
        formattedEnd = endDate.getFullYear().toString();
      } else if (precision === 'month') {
        formattedEnd = endDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long' });
      } else {
        formattedEnd = endDate.toLocaleDateString('es-MX', { year: 'numeric', month: 'long', day: 'numeric' });
      }
      return `${formattedStart} - ${formattedEnd}`;
    }

    return formattedStart;
  };

  const extractExcerpt = (content: string, maxLength: number = 150): string => {
    const text = content.replace(/<[^>]*>/g, '').replace(/\n+/g, ' ').trim();
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength).trim() + '...';
  };

  const storyDateFormatted = formatStoryDate(story);
  const excerpt = extractExcerpt(story.content);

  return (
    <motion.a
      ref={ref}
      href={`/blog/story/${story.id}${window.location.search}`}
      initial={{ opacity: 0, y: 30, scale: 0.95 }}
      animate={isInView ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 30, scale: 0.95 }}
      transition={{
        duration: 0.5,
        ease: [0.21, 0.47, 0.32, 0.98]
      }}
      whileHover={{
        y: -8,
        scale: 1.03,
        boxShadow: "0 20px 40px -12px rgba(0, 0, 0, 0.15)"
      }}
      className="block bg-white rounded-2xl shadow-soft-hover overflow-hidden group"
    >
      {/* Solo mostrar imagen si existe */}
      {story.photos && story.photos.length > 0 && (
        <div className="h-48 overflow-hidden relative">
          <img
            src={story.photos[0].photoUrl}
            alt={story.title}
            className="w-full h-full object-cover transform group-hover:scale-110 transition-transform duration-700"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500"></div>
        </div>
      )}
      <div className="p-6" style={{ borderTop: story.photos && story.photos.length > 0 ? 'none' : `4px solid ${NarraColors.brand.primary}` }}>
        <h3 className="text-xl font-bold mb-3 line-clamp-2 transition-colors duration-300" style={{ color: NarraColors.text.primary, fontFamily: "'Playfair Display', serif" }}>
          {story.title}
        </h3>

        {excerpt && (
          <p className="text-sm mb-4 line-clamp-2 leading-relaxed" style={{ color: NarraColors.text.secondary, lineHeight: '1.6' }}>
            {excerpt}
          </p>
        )}

        <div className="flex flex-col gap-2 mb-4">
          <div className="flex flex-wrap items-center gap-2">
            {storyDateFormatted && (
              <div className="flex items-center gap-1 px-3 py-1 rounded-full text-xs font-semibold transform group-hover:scale-105 transition-transform" style={{ backgroundColor: NarraColors.brand.primaryLight, color: NarraColors.brand.primarySolid }}>
                <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <time>{storyDateFormatted}</time>
              </div>
            )}

            {story.tags && story.tags.length > 0 && (
              <>
                {story.tags.slice(0, 2).map((tag, idx) => (
                  <span
                    key={tag.id}
                    className="px-3 py-1 text-xs rounded-full font-semibold transform group-hover:scale-105 transition-all"
                    style={{
                      backgroundColor: NarraColors.brand.primaryLight,
                      color: NarraColors.brand.primarySolid,
                      transitionDelay: `${idx * 50}ms`
                    }}
                  >
                    #{tag.name || tag.tag}
                  </span>
                ))}
              </>
            )}
          </div>
          {story.publishedAt && (
            <p className="text-xs italic flex items-center gap-1" style={{ color: NarraColors.text.light }}>
              <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Publicado el {formatDate(story.publishedAt)}
            </p>
          )}
        </div>

        <div
          className="text-sm font-semibold flex items-center gap-2 transform group-hover:gap-3 transition-all duration-300"
          style={{ color: NarraColors.brand.primary }}
        >
          Leer historia
          <svg className="w-4 h-4 transform group-hover:translate-x-1 transition-transform duration-300" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </div>
      </div>
    </motion.a>
  );
};
