import { Navigate } from 'react-router-dom';

const ProtectedRoute = ({ children }: { children: React.ReactNode }) => {
  // Check if user has an API key in localStorage
  const apiKey = localStorage.getItem('apiKey');

  // If no API key, redirect to login
  if (!apiKey) {
    return <Navigate to="/login" replace />;
  }

  // If API key exists, allow access
  // The API client will handle validation on actual requests
  return children;
};

export default ProtectedRoute;