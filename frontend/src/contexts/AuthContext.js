import React, { createContext, useContext, useState, useEffect } from 'react';
import axios from 'axios';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const AuthContext = createContext(null);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Configure axios interceptor for auth token
  useEffect(() => {
    const token = localStorage.getItem('access_token');
    if (token) {
      axios.defaults.headers.common['Authorization'] = `Bearer ${token}`;
    }

    // Add response interceptor to handle token expiry
    const responseInterceptor = axios.interceptors.response.use(
      (response) => response,
      async (error) => {
        if (error.response?.status === 401) {
          // Token expired, try to refresh
          const refreshToken = localStorage.getItem('refresh_token');
          if (refreshToken) {
            try {
              const response = await axios.post(`${API}/auth/refresh`, {
                refresh_token: refreshToken
              });
              
              const { access_token } = response.data;
              localStorage.setItem('access_token', access_token);
              axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
              
              // Retry original request
              error.config.headers['Authorization'] = `Bearer ${access_token}`;
              return axios.request(error.config);
            } catch (refreshError) {
              // Refresh failed, logout user
              logout();
            }
          } else {
            logout();
          }
        }
        return Promise.reject(error);
      }
    );

    return () => {
      axios.interceptors.response.eject(responseInterceptor);
    };
  }, []);

  // Check if user is authenticated on app load
  useEffect(() => {
    const checkAuth = async () => {
      const token = localStorage.getItem('access_token');
      if (token) {
        try {
          const response = await axios.get(`${API}/auth/me`);
          setUser(response.data);
          setIsAuthenticated(true);
        } catch (error) {
          // Token invalid, remove from storage
          localStorage.removeItem('access_token');
          localStorage.removeItem('refresh_token');
          delete axios.defaults.headers.common['Authorization'];
        }
      }
      setIsLoading(false);
    };

    checkAuth();
  }, []);

  const login = async (credentials) => {
    try {
      const response = await axios.post(`${API}/auth/login`, credentials);
      const { access_token, refresh_token, user: userData } = response.data;

      // Store tokens
      localStorage.setItem('access_token', access_token);
      localStorage.setItem('refresh_token', refresh_token);
      
      // Set authorization header
      axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
      
      // Update state
      setUser(userData);
      setIsAuthenticated(true);

      return { success: true, user: userData };
    } catch (error) {
      const message = error.response?.data?.detail || 'Erro ao fazer login';
      return { success: false, error: message };
    }
  };

  const signup = async (userData) => {
    try {
      const response = await axios.post(`${API}/auth/signup`, userData);
      const { access_token, refresh_token, user: newUser } = response.data;

      // Store tokens
      localStorage.setItem('access_token', access_token);
      localStorage.setItem('refresh_token', refresh_token);
      
      // Set authorization header
      axios.defaults.headers.common['Authorization'] = `Bearer ${access_token}`;
      
      // Update state
      setUser(newUser);
      setIsAuthenticated(true);

      return { success: true, user: newUser };
    } catch (error) {
      const message = error.response?.data?.detail || 'Erro ao criar conta';
      return { success: false, error: message };
    }
  };

  const logout = () => {
    // Clear tokens
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    
    // Remove authorization header
    delete axios.defaults.headers.common['Authorization'];
    
    // Update state
    setUser(null);
    setIsAuthenticated(false);
  };

  const oauthLogin = async (provider) => {
    try {
      const response = await axios.get(`${API}/auth/oauth/${provider}`);
      const { auth_url, state } = response.data;
      
      // Store state for validation
      localStorage.setItem(`oauth_state_${provider}`, state);
      
      // Redirect to OAuth provider
      window.location.href = auth_url;
    } catch (error) {
      console.error(`OAuth login error for ${provider}:`, error);
      return { success: false, error: `Erro ao conectar com ${provider}` };
    }
  };

  const disconnectOAuth = async (provider) => {
    try {
      await axios.delete(`${API}/auth/oauth/${provider}`);
      return { success: true };
    } catch (error) {
      const message = error.response?.data?.detail || `Erro ao desconectar ${provider}`;
      return { success: false, error: message };
    }
  };

  const getOAuthStatus = async () => {
    try {
      const response = await axios.get(`${API}/auth/oauth/status`);
      return { success: true, data: response.data };
    } catch (error) {
      return { success: false, error: 'Erro ao buscar status OAuth' };
    }
  };

  const value = {
    user,
    isLoading,
    isAuthenticated,
    login,
    signup,
    logout,
    oauthLogin,
    disconnectOAuth,
    getOAuthStatus
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};