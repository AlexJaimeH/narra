import React, { useState } from 'react';
import { StoryFeedbackComment } from '../types';

interface CommentsProps {
  comments: StoryFeedbackComment[];
  onSubmitComment: (content: string, parentCommentId?: string) => Promise<void>;
  isSubmitting: boolean;
}

interface CommentItemProps {
  comment: StoryFeedbackComment;
  onReply: (commentId: string, content: string) => Promise<void>;
  depth: number;
}

const formatDate = (dateString: string): string => {
  const date = new Date(dateString);
  const now = new Date();
  const diffInMs = now.getTime() - date.getTime();
  const diffInHours = diffInMs / (1000 * 60 * 60);

  if (diffInHours < 24) {
    const hours = Math.floor(diffInHours);
    if (hours === 0) {
      const minutes = Math.floor(diffInMs / (1000 * 60));
      return minutes <= 1 ? 'hace un momento' : `hace ${minutes} minutos`;
    }
    return hours === 1 ? 'hace 1 hora' : `hace ${hours} horas`;
  }

  return date.toLocaleDateString('es-MX', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });
};

const CommentItem: React.FC<CommentItemProps> = ({ comment, onReply, depth }) => {
  const [showReplyForm, setShowReplyForm] = useState(false);
  const [replyContent, setReplyContent] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleSubmitReply = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!replyContent.trim() || isSubmitting) return;

    setIsSubmitting(true);
    try {
      await onReply(comment.id, replyContent);
      setReplyContent('');
      setShowReplyForm(false);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div className={`${depth > 0 ? 'ml-8 mt-4' : 'mt-6'}`}>
      <div className="flex gap-3">
        <div className="flex-shrink-0 w-10 h-10 rounded-full bg-brand-primary/20 flex items-center justify-center text-brand-primary font-semibold">
          {comment.subscriberName[0].toUpperCase()}
        </div>

        <div className="flex-1">
          <div className="bg-surface-paper rounded-lg p-4">
            <div className="flex items-center gap-2 mb-2">
              <span className="font-semibold text-text-primary">{comment.subscriberName}</span>
              <span className="text-sm text-text-light">{formatDate(comment.createdAt)}</span>
            </div>
            <p className="text-text-secondary whitespace-pre-wrap">{comment.content}</p>
          </div>

          {depth < 2 && (
            <button
              onClick={() => setShowReplyForm(!showReplyForm)}
              className="text-sm text-brand-primary hover:text-brand-primary-hover font-medium mt-2"
            >
              Responder
            </button>
          )}

          {showReplyForm && (
            <form onSubmit={handleSubmitReply} className="mt-3">
              <textarea
                value={replyContent}
                onChange={(e) => setReplyContent(e.target.value)}
                placeholder="Escribe tu respuesta..."
                className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-brand-primary focus:border-transparent resize-none"
                rows={3}
                disabled={isSubmitting}
              />
              <div className="flex gap-2 mt-2">
                <button
                  type="submit"
                  disabled={!replyContent.trim() || isSubmitting}
                  className="btn-primary text-sm py-2 px-4 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  {isSubmitting ? 'Enviando...' : 'Responder'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setShowReplyForm(false);
                    setReplyContent('');
                  }}
                  className="btn-secondary text-sm py-2 px-4"
                >
                  Cancelar
                </button>
              </div>
            </form>
          )}
        </div>
      </div>

      {comment.replies.length > 0 && (
        <div className="mt-2">
          {comment.replies.map(reply => (
            <CommentItem
              key={reply.id}
              comment={reply}
              onReply={onReply}
              depth={depth + 1}
            />
          ))}
        </div>
      )}
    </div>
  );
};

export const Comments: React.FC<CommentsProps> = ({
  comments,
  onSubmitComment,
  isSubmitting,
}) => {
  const [newComment, setNewComment] = useState('');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newComment.trim() || isSubmitting) return;

    await onSubmitComment(newComment);
    setNewComment('');
  };

  const handleReply = async (parentCommentId: string, content: string) => {
    await onSubmitComment(content, parentCommentId);
  };

  return (
    <div className="mt-12">
      <h3 className="text-2xl font-bold text-text-primary mb-6">
        Comentarios {comments.length > 0 && `(${comments.length})`}
      </h3>

      <form onSubmit={handleSubmit} className="mb-8">
        <textarea
          value={newComment}
          onChange={(e) => setNewComment(e.target.value)}
          placeholder="Escribe un comentario..."
          className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-brand-primary focus:border-transparent resize-none"
          rows={4}
          disabled={isSubmitting}
        />
        <button
          type="submit"
          disabled={!newComment.trim() || isSubmitting}
          className="btn-primary mt-3 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {isSubmitting ? 'Enviando...' : 'Publicar comentario'}
        </button>
      </form>

      {comments.length === 0 ? (
        <p className="text-center text-text-light py-8">
          Sé el primero en comentar esta historia
        </p>
      ) : (
        <div className="space-y-2">
          {comments.map(comment => (
            <CommentItem
              key={comment.id}
              comment={comment}
              onReply={handleReply}
              depth={0}
            />
          ))}
        </div>
      )}
    </div>
  );
};
