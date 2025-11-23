import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { LandingPage } from './pages/LandingPage';
import { BlogHome } from './pages/BlogHome';
import { StoryPage } from './pages/StoryPage';
import { EmailChangeConfirm } from './pages/EmailChangeConfirm';
import { EmailChangeRevert } from './pages/EmailChangeRevert';
import { PurchasePage } from './pages/PurchasePage';
import { PurchaseCheckoutPage } from './pages/PurchaseCheckoutPage';
import { PurchaseSuccessPage } from './pages/PurchaseSuccessPage';
import { GiftActivationPage } from './pages/GiftActivationPage';
import { GiftManagementPage } from './pages/GiftManagementPage';
import { TermsPage } from './pages/TermsPage';
import { PrivacyPage } from './pages/PrivacyPage';
import { ContactPage } from './pages/ContactPage';

const App: React.FC = () => {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<LandingPage />} />
        <Route path="/blog/subscriber/:subscriberId" element={<BlogHome />} />
        <Route path="/blog/story/:storyId" element={<StoryPage />} />
        <Route path="/email-change-confirm" element={<EmailChangeConfirm />} />
        <Route path="/email-change-revert" element={<EmailChangeRevert />} />
        <Route path="/purchase" element={<PurchasePage />} />
        <Route path="/purchase/checkout" element={<PurchaseCheckoutPage />} />
        <Route path="/purchase/success" element={<PurchaseSuccessPage />} />
        <Route path="/gift-activation" element={<GiftActivationPage />} />
        <Route path="/gift-management" element={<GiftManagementPage />} />
        <Route path="/terminos" element={<TermsPage />} />
        <Route path="/privacidad" element={<PrivacyPage />} />
        <Route path="/contacto" element={<ContactPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
};

export default App;
