import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { BlogHome } from './pages/BlogHome';
import { StoryPage } from './pages/StoryPage';

const App: React.FC = () => {
  return (
    <BrowserRouter basename="/blog">
      <Routes>
        <Route path="/subscriber/:subscriberId" element={<BlogHome />} />
        <Route path="/story/:storyId" element={<StoryPage />} />
        <Route path="*" element={<Navigate to="/blog" replace />} />
      </Routes>
    </BrowserRouter>
  );
};

export default App;
