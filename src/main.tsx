// src/main.tsx
import { ClerkProvider } from '@clerk/clerk-react';
import ReactDOM from 'react-dom/client';
import App from './App';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <ClerkProvider publishableKey={process.env.CLERK_PUBLISHABLE_KEY!}>
    <App />
  </ClerkProvider>
);
