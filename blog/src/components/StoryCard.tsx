import React from 'react';
import { Link } from 'react-router-dom';
import { Story } from '../types';

interface StoryCardProps {
  story: Story;
}

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

const formatPublishedDate = (dateString: string | null): string => {
  if (!dateString) return '';
  const date = new Date(dateString);
  return date.toLocaleDateString('es-MX', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
};

const extractExcerpt = (content: string, maxLength: number = 200): string => {
  const text = content.replace(/<[^>]*>/g, '').replace(/\n+/g, ' ').trim();
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength).trim() + '...';
};

export const StoryCard: React.FC<StoryCardProps> = ({ story }) => {
  const storyDateFormatted = formatStoryDate(story);
  const excerpt = extractExcerpt(story.content);
  const featuredImage = story.photos?.[0]?.photoUrl;

  return (
    <Link to={`/blog/story/${story.id}${window.location.search}`} className="block">
      <article className="card p-6 hover:shadow-lg transition-all duration-200">
        <div className="flex flex-col gap-4">
          {featuredImage && (
            <div className="w-full aspect-video overflow-hidden rounded-lg">
              <img
                src={featuredImage}
                alt={story.title}
                className="w-full h-full object-cover"
              />
            </div>
          )}

          <div className="flex-1">
            <h2 className="text-2xl font-bold text-text-primary mb-2 hover:text-brand-primary transition-colors">
              {story.title}
            </h2>

            <div className="flex flex-wrap items-center gap-3 mb-3">
              {storyDateFormatted && (
                <div className="flex items-center gap-2 px-3 py-1.5 bg-brand-primary/15 text-brand-primary text-sm font-medium rounded-full">
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                  </svg>
                  <time>{storyDateFormatted}</time>
                </div>
              )}

              {story.tags && story.tags.length > 0 && (
                <div className="flex flex-wrap gap-2">
                  {story.tags.map(tag => (
                    <span
                      key={tag.id}
                      className="px-3 py-1.5 bg-brand-primary/10 text-brand-primary text-sm rounded-full font-medium"
                    >
                      #{tag.name || tag.tag}
                    </span>
                  ))}
                </div>
              )}
            </div>

            <p className="text-text-secondary leading-relaxed mb-3">
              {excerpt}
            </p>

            <div className="flex flex-col gap-2">
              <div className="flex items-center gap-4 text-sm text-text-light">
                {story.commentCount !== undefined && story.commentCount > 0 && (
                  <span>{story.commentCount} comentario{story.commentCount !== 1 ? 's' : ''}</span>
                )}
                {story.reactionCount !== undefined && story.reactionCount > 0 && (
                  <span>♥ {story.reactionCount}</span>
                )}
              </div>
              {story.publishedAt && (
                <p className="text-xs text-text-light italic">
                  Publicado el {formatPublishedDate(story.publishedAt)}
                </p>
              )}
            </div>
          </div>
        </div>
      </article>
    </Link>
  );
};
