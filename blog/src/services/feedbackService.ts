import { StoryFeedbackState, StoryFeedbackComment } from '../types';

const API_BASE = '/api';

interface FetchStateParams {
  authorId: string;
  storyId: string;
  subscriberId: string;
  token: string;
  source?: string;
}

interface SubmitCommentParams extends FetchStateParams {
  content: string;
  parentCommentId?: string;
}

interface ToggleReactionParams extends FetchStateParams {
  reactionType?: string;
}

export const feedbackService = {
  async fetchState(params: FetchStateParams): Promise<StoryFeedbackState> {
    try {
      const queryParams = new URLSearchParams({
        authorId: params.authorId,
        storyId: params.storyId,
        subscriberId: params.subscriberId,
        token: params.token,
        ...(params.source && { source: params.source }),
      });

      const response = await fetch(`${API_BASE}/story-feedback?${queryParams}`);

      if (!response.ok) {
        return {
          hasReacted: false,
          reactionCount: 0,
          commentCount: 0,
          comments: [],
        };
      }

      const contentType = response.headers.get('content-type');
      if (!contentType || !contentType.includes('application/json')) {
        return {
          hasReacted: false,
          reactionCount: 0,
          commentCount: 0,
          comments: [],
        };
      }

      const data = await response.json();
      return {
        hasReacted: data.hasReacted || false,
        reactionCount: data.reactionCount || 0,
        commentCount: data.commentCount || 0,
        comments: this.buildCommentTree(data.comments || []),
      };
    } catch (error) {
      return {
        hasReacted: false,
        reactionCount: 0,
        commentCount: 0,
        comments: [],
      };
    }
  },

  async submitComment(params: SubmitCommentParams): Promise<boolean> {
    try {
      const response = await fetch(`${API_BASE}/story-feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action: 'comment',
          authorId: params.authorId,
          storyId: params.storyId,
          subscriberId: params.subscriberId,
          token: params.token,
          content: params.content,
          parentCommentId: params.parentCommentId,
          source: params.source,
        }),
      });

      return response.ok;
    } catch (error) {
      return false;
    }
  },

  async toggleReaction(params: ToggleReactionParams): Promise<boolean> {
    try {
      const response = await fetch(`${API_BASE}/story-feedback`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          action: 'reaction',
          authorId: params.authorId,
          storyId: params.storyId,
          subscriberId: params.subscriberId,
          token: params.token,
          reactionType: params.reactionType || 'heart',
          source: params.source,
        }),
      });

      return response.ok;
    } catch (error) {
      return false;
    }
  },

  buildCommentTree(comments: any[]): StoryFeedbackComment[] {
    const commentMap = new Map<string, StoryFeedbackComment>();
    const rootComments: StoryFeedbackComment[] = [];

    // First pass: create all comment objects
    for (const comment of comments) {
      const feedbackComment: StoryFeedbackComment = {
        id: comment.id,
        storyId: comment.storyId || comment.story_id,
        subscriberId: comment.subscriberId || comment.subscriber_id,
        subscriberName: comment.subscriberName || comment.subscriber_name || 'Lector',
        content: comment.content,
        parentCommentId: comment.parentCommentId || comment.parent_comment_id,
        createdAt: comment.createdAt || comment.created_at,
        replies: [],
      };
      commentMap.set(feedbackComment.id, feedbackComment);
    }

    // Second pass: build tree structure
    for (const comment of commentMap.values()) {
      if (comment.parentCommentId) {
        const parent = commentMap.get(comment.parentCommentId);
        if (parent) {
          parent.replies.push(comment);
        } else {
          rootComments.push(comment);
        }
      } else {
        rootComments.push(comment);
      }
    }

    // Sort comments by date (newest first)
    const sortComments = (comments: StoryFeedbackComment[]) => {
      comments.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
      comments.forEach(comment => {
        if (comment.replies.length > 0) {
          sortComments(comment.replies);
        }
      });
    };

    sortComments(rootComments);
    return rootComments;
  },
};
