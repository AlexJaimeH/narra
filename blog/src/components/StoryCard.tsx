import React from 'react';
import { Link } from 'react-router-dom';
import { Story } from '../types';

interface StoryCardProps {
  story: Story;
}

const formatDate = (dateString: string | null): string => {
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
  const publishDate = formatDate(story.publishedAt);
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

            {publishDate && (
              <time className="text-sm text-text-light mb-3 block">
                {publishDate}
              </time>
            )}

            <p className="text-text-secondary leading-relaxed">
              {excerpt}
            </p>

            {story.tags && story.tags.length > 0 && (
              <div className="flex flex-wrap gap-2 mt-4">
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

            <div className="flex items-center gap-4 mt-4 text-sm text-text-light">
              {story.commentCount !== undefined && story.commentCount > 0 && (
                <span>{story.commentCount} comentario{story.commentCount !== 1 ? 's' : ''}</span>
              )}
              {story.reactionCount !== undefined && story.reactionCount > 0 && (
                <span>♥ {story.reactionCount}</span>
              )}
            </div>
          </div>
        </div>
      </article>
    </Link>
  );
};
