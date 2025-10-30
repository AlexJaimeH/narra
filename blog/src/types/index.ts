export interface Story {
  id: string;
  userId: string;
  title: string;
  content: string;
  status: 'draft' | 'published';
  publishedAt: string | null;
  createdAt: string;
  updatedAt: string;
  authorName?: string;
  authorDisplayName?: string;
  authorAvatarUrl?: string;
  photos?: StoryPhoto[];
  tags?: StoryTag[];
  commentCount?: number;
  reactionCount?: number;
  storyDate?: string | null;
  startDate?: string | null;
  endDate?: string | null;
  datesPrecision?: 'day' | 'month' | 'year';
}

export interface StoryPhoto {
  id: string;
  storyId: string;
  photoUrl: string;
  caption?: string;
  displayOrder: number;
  createdAt: string;
}

export interface StoryTag {
  id: string;
  storyId: string;
  tag: string;
  name: string;
  color?: string;
  createdAt: string;
}

export interface PublicAuthorProfile {
  userId: string;
  displayName: string;
  name: string;
  avatarUrl?: string;
  tagline?: string;
  summary?: string;
  coverImageUrl?: string;
}

export interface StorySharePayload {
  subscriberId: string;
  subscriberName?: string;
  token?: string;
  source?: string;
}

export interface StoryAccessRecord {
  authorId: string;
  subscriberId: string;
  subscriberName?: string;
  accessToken: string;
  source?: string;
  grantedAt: string;
  status: 'active' | 'revoked';
  supabaseUrl?: string;
  supabaseAnonKey?: string;
  isAuthor?: boolean;
}

export interface StoryFeedbackComment {
  id: string;
  storyId: string;
  subscriberId: string;
  subscriberName: string;
  content: string;
  parentCommentId?: string;
  createdAt: string;
  replies: StoryFeedbackComment[];
}

export interface StoryFeedbackState {
  hasReacted: boolean;
  reactionCount: number;
  commentCount: number;
  comments: StoryFeedbackComment[];
}
