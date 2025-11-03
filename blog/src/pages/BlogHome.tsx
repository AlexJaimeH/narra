import React, { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { motion, useInView } from 'framer-motion';
import { Loading } from '../components/Loading';
import { ErrorMessage } from '../components/ErrorMessage';
import { Story, PublicAuthorProfile } from '../types';
import { publicAccessService } from '../services/publicAccessService';
import { accessManager } from '../services/accessManager';
import { storyService } from '../services/storyService';
import { feedbackService } from '../services/feedbackService';
import { NarraColors } from '../styles/colors';

interface StoryWithFeedback extends Story {
  reactionCount?: number;
  commentCount?: number;
}

export const BlogHome: React.FC = () => {
  const { subscriberId } = useParams<{ subscriberId?: string }>();
  const navigate = useNavigate();
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [stories, setStories] = useState<StoryWithFeedback[]>([]);
  const [author, setAuthor] = useState<PublicAuthorProfile | null>(null);
  const [subscriberName, setSubscriberName] = useState<string | null>(null);
  const [showUnsubscribeConfirm, setShowUnsubscribeConfirm] = useState(false);
  const [showUnsubscribeSuccess, setShowUnsubscribeSuccess] = useState(false);
  const [isUnsubscribing, setIsUnsubscribing] = useState(false);

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

      // Load feedback for each story
      const storiesWithFeedback = await Promise.all(
        loadedStories.map(async (story) => {
          try {
            const feedbackState = await feedbackService.fetchState({
              authorId: urlParams.authorId!,
              storyId: story.id,
              subscriberId: accessRecord.subscriberId,
              token: accessRecord.accessToken,
              source: accessRecord.source,
            });
            return {
              ...story,
              reactionCount: feedbackState.reactionCount,
              commentCount: feedbackState.commentCount,
            };
          } catch {
            return {
              ...story,
              reactionCount: 0,
              commentCount: 0,
            };
          }
        })
      );

      setStories(storiesWithFeedback);
      setIsLoading(false);
    } catch (err) {
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

  if (isLoading) return <Loading />;
  if (error) return <ErrorMessage message={error} onRetry={loadBlog} />;

  return (
    <div className="min-h-screen smooth-scroll" style={{ background: `linear-gradient(to bottom, ${NarraColors.brand.primaryPale}, ${NarraColors.surface.white})` }}>
      {/* Header del blog mejorado */}
      <header
        className="relative overflow-hidden"
        style={{
          background: `linear-gradient(135deg, ${NarraColors.brand.primary}15 0%, ${NarraColors.brand.accent}10 100%)`,
        }}
      >
        <div className="absolute inset-0 opacity-5" style={{ backgroundImage: 'url("data:image/svg+xml,%3Csvg width="60" height="60" viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg"%3E%3Cg fill="none" fill-rule="evenodd"%3E%3Cg fill="%234DB3A8" fill-opacity="1"%3E%3Cpath d="M36 34v-4h-2v4h-4v2h4v4h2v-4h4v-2h-4zm0-30V0h-2v4h-4v2h4v4h2V6h4V4h-4zM6 34v-4H4v4H0v2h4v4h2v-4h4v-2H6zM6 4V0H4v4H0v2h4v4h2V6h4V4H6z"/%3E%3C/g%3E%3C/g%3E%3C/svg%3E")' }}></div>

        <div className="relative max-w-5xl mx-auto px-4 py-20 text-center">
          <motion.div
            initial={{ opacity: 0, scale: 0.8, y: 20 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            transition={{ duration: 0.6, ease: [0.21, 0.47, 0.32, 0.98] }}
            className="mb-8 inline-block"
          >
            {author?.avatarUrl ? (
              <motion.div
                whileHover={{ scale: 1.1, rotate: 5 }}
                transition={{ type: "spring", stiffness: 300 }}
                className="relative"
              >
                <img
                  src={author.avatarUrl}
                  alt={author.displayName}
                  className="w-32 h-32 rounded-full mx-auto object-cover border-8 border-white shadow-2xl transform transition-transform hover:scale-105"
                />
                <motion.div
                  animate={{ y: [0, -10, 0] }}
                  transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                  className="absolute -bottom-2 -right-2 w-12 h-12 rounded-full flex items-center justify-center shadow-xl"
                  style={{ backgroundColor: NarraColors.brand.primary }}
                >
                  <svg className="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z" />
                  </svg>
                </motion.div>
              </motion.div>
            ) : (
              <motion.div
                whileHover={{ scale: 1.1, rotate: 5 }}
                transition={{ type: "spring", stiffness: 300 }}
                className="w-32 h-32 rounded-full mx-auto flex items-center justify-center text-white text-5xl font-bold shadow-2xl border-8 border-white"
                style={{ backgroundColor: NarraColors.brand.primary }}
              >
                {author?.displayName?.[0] || 'A'}
              </motion.div>
            )}
          </motion.div>

          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.2 }}
            className="text-5xl md:text-6xl font-bold mb-4"
            style={{
              background: 'linear-gradient(135deg, #1F2937 0%, #4B5563 50%, #1F2937 100%)',
              WebkitBackgroundClip: 'text',
              backgroundClip: 'text',
              WebkitTextFillColor: 'transparent'
            }}
          >
            Historias de {author?.displayName}
          </motion.h1>

          {author?.tagline && (
            <motion.p
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.7, delay: 0.4 }}
              className="text-xl md:text-2xl mb-6 font-medium"
              style={{ color: NarraColors.text.secondary }}
            >
              {author.tagline}
            </motion.p>
          )}

          {subscriberName && (
            <motion.div
              initial={{ opacity: 0, scale: 0.8 }}
              animate={{ opacity: 1, scale: 1 }}
              transition={{ duration: 0.5, delay: 0.6 }}
              whileHover={{ scale: 1.05 }}
              className="inline-flex items-center gap-2 px-6 py-3 rounded-full shadow-lg glass"
              style={{ color: NarraColors.brand.primarySolid }}
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
              <span className="font-semibold">Hola, {subscriberName}</span>
            </motion.div>
          )}

          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.8 }}
            whileHover={{ scale: 1.08, rotate: 2 }}
            className="mt-8 inline-flex items-center gap-3 px-8 py-4 rounded-full shadow-xl"
            style={{ backgroundColor: NarraColors.brand.primary, color: 'white' }}
          >
            <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </svg>
            <span className="text-lg font-bold">{stories.length}</span>
            <span className="text-lg">{stories.length === 1 ? 'historia publicada' : 'historias publicadas'}</span>
          </motion.div>
        </div>
      </header>

      {/* Contenido principal */}
      <main className="max-w-5xl mx-auto px-4 py-12">
        {stories.length === 0 ? (
          <motion.div
            initial={{ opacity: 0, scale: 0.9 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.5 }}
            className="text-center py-20 bg-white/80 backdrop-blur rounded-3xl shadow-xl"
          >
            <motion.svg
              animate={{
                y: [0, -10, 0],
                rotate: [0, 5, -5, 0]
              }}
              transition={{
                duration: 4,
                repeat: Infinity,
                ease: "easeInOut"
              }}
              className="w-24 h-24 mx-auto mb-6 opacity-50"
              style={{ color: NarraColors.brand.primary }}
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
            </motion.svg>
            <p className="text-2xl mb-3 font-semibold" style={{ color: NarraColors.text.secondary }}>
              Aún no hay historias publicadas
            </p>
            <p style={{ color: NarraColors.text.light }}>
              Vuelve pronto para descubrir nuevas historias
            </p>
          </motion.div>
        ) : (
          <div className="space-y-8">
            {stories.map((story, index) => (
              <StoryCard
                key={story.id}
                story={story}
                index={index}
                formatDate={formatDate}
              />
            ))}
          </div>
        )}

        {/* Desuscripción - Solo mostrar si no es el autor */}
        {!accessManager.getAccess()?.isAuthor && (
          <div className="mt-16 bg-white/50 backdrop-blur rounded-3xl p-8 text-center border border-gray-100 shadow-lg">
            <p className="text-lg mb-4" style={{ color: NarraColors.text.secondary }}>
              ¿No deseas recibir más historias de {author?.displayName}?
            </p>
            <button
              onClick={handleUnsubscribe}
              className="text-sm underline hover:no-underline transition-all font-medium"
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

// Componente de card de historia mejorado con animaciones
const StoryCard: React.FC<{
  story: StoryWithFeedback;
  index: number;
  formatDate: (date: string | null) => string;
}> = ({ story, index, formatDate }) => {
  const ref = React.useRef(null);
  const isInView = useInView(ref, { once: true, margin: "-100px" });

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

  const storyDateFormatted = formatStoryDate(story);

  return (
    <motion.article
      ref={ref}
      initial={{ opacity: 0, y: 50, scale: 0.95 }}
      animate={isInView ? { opacity: 1, y: 0, scale: 1 } : { opacity: 0, y: 50, scale: 0.95 }}
      transition={{
        duration: 0.6,
        delay: index * 0.15,
        ease: [0.21, 0.47, 0.32, 0.98]
      }}
      whileHover={{
        y: -8,
        scale: 1.02,
        boxShadow: "0 25px 50px -12px rgba(0, 0, 0, 0.15)"
      }}
      className="group bg-white rounded-3xl shadow-soft-hover overflow-hidden"
    >
      <a href={`/blog/story/${story.id}${window.location.search}`} className="block">
        {/* Imagen de portada - solo si existe */}
        {story.photos && story.photos.length > 0 && (
          <div className="relative h-80 overflow-hidden">
            <img
              src={story.photos[0].photoUrl}
              alt={story.title}
              className="w-full h-full object-cover transform group-hover:scale-110 transition-transform duration-700"
            />
            <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent"></div>

            {/* Decorative corner element */}
            <div className="absolute top-0 right-0 w-32 h-32 bg-gradient-to-br from-white/10 to-transparent"></div>
          </div>
        )}

        <div className="p-8">
          {/* Metadata */}
          <div className="flex flex-wrap items-center gap-3 mb-5">
            {storyDateFormatted && (
              <div className="flex items-center gap-2 px-4 py-2 rounded-full text-sm font-semibold transform group-hover:scale-105 transition-transform" style={{ backgroundColor: NarraColors.brand.primaryLight, color: NarraColors.brand.primarySolid }}>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                <time>{storyDateFormatted}</time>
              </div>
            )}

            {/* Conteos */}
            <div className="flex items-center gap-3">
              {(story.reactionCount ?? 0) > 0 && (
                <div className="flex items-center gap-2 px-3 py-2 rounded-full transform group-hover:scale-105 transition-transform" style={{ backgroundColor: NarraColors.interactive.heartLight, color: NarraColors.interactive.heart }}>
                  <svg className="w-4 h-4 animate-pulse-soft" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clipRule="evenodd" />
                  </svg>
                  <span className="text-sm font-bold">{story.reactionCount}</span>
                </div>
              )}

              {(story.commentCount ?? 0) > 0 && (
                <div className="flex items-center gap-2 px-3 py-2 rounded-full transform group-hover:scale-105 transition-transform" style={{ backgroundColor: NarraColors.brand.primaryLight, color: NarraColors.brand.primarySolid }}>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z" />
                  </svg>
                  <span className="text-sm font-bold">{story.commentCount}</span>
                </div>
              )}
            </div>
          </div>

          {/* Título */}
          <h2 className="text-3xl md:text-4xl font-bold mb-5 leading-tight transition-all duration-300" style={{
            color: NarraColors.text.primary,
            fontFamily: "'Playfair Display', serif"
          }}>
            {story.title}
          </h2>

          {/* Contenido preview */}
          <div
            className="prose prose-lg line-clamp-3 mb-6 leading-relaxed transition-colors duration-300"
            style={{ color: NarraColors.text.secondary, lineHeight: '1.8' }}
            dangerouslySetInnerHTML={{ __html: story.content }}
          />

          {/* Tags */}
          {story.tags && story.tags.length > 0 && (
            <div className="flex flex-wrap gap-2 mb-6">
              {story.tags.map((tag, idx) => (
                <span
                  key={tag.id}
                  className="px-4 py-2 text-sm rounded-full font-semibold shadow-sm transform group-hover:scale-105 transition-all"
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

          {/* Fecha de publicación */}
          {story.publishedAt && (
            <p className="text-sm italic mb-6 flex items-center gap-2" style={{ color: NarraColors.text.light }}>
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              Publicado el {formatDate(story.publishedAt)}
            </p>
          )}

          {/* CTA */}
          <div
            className="inline-flex items-center gap-2 text-lg font-bold group-hover:gap-4 transition-all duration-300 transform group-hover:translate-x-2"
            style={{ color: NarraColors.brand.primary }}
          >
            Leer historia completa
            <svg
              className="w-5 h-5 transform group-hover:translate-x-1 transition-transform duration-300"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 7l5 5m0 0l-5 5m5-5H6" />
            </svg>
          </div>
        </div>
      </a>
    </motion.article>
  );
};
