import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { LandingPage } from './pages/LandingPage';
import { BlogHome } from './pages/BlogHome';
import { StoryPage } from './pages/StoryPage';
import { EmailChangeConfirm } from './pages/EmailChangeConfirm';
import { EmailChangeRevert } from './pages/EmailChangeRevert';

const App: React.FC = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/blog/subscriber/:subscriberId" element={<BlogHome />} />
        <Route path="/blog/story/:storyId" element={<StoryPage />} />
        <Route path="/email-change-confirm" element={<EmailChangeConfirm />} />
        <Route path="/email-change-revert" element={<EmailChangeRevert />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
};

export default App;
