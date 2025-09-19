import React, { useState, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import axios from 'axios';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const Dashboard = () => {
  const { user, logout, getOAuthStatus, oauthLogin, disconnectOAuth } = useAuth();
  const [oauthStatus, setOauthStatus] = useState({});
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const fetchOAuthStatus = async () => {
      const result = await getOAuthStatus();
      if (result.success) {
        setOauthStatus(result.data);
      }
      setIsLoading(false);
    };

    fetchOAuthStatus();
  }, [getOAuthStatus]);

  const handleConnectProvider = async (provider) => {
    await oauthLogin(provider);
  };

  const handleDisconnectProvider = async (provider) => {
    const result = await disconnectOAuth(provider);
    if (result.success) {
      // Refresh OAuth status
      const statusResult = await getOAuthStatus();
      if (statusResult.success) {
        setOauthStatus(statusResult.data);
      }
    }
  };

  const formatDate = (dateString) => {
    if (!dateString) return 'N/A';
    return new Date(dateString).toLocaleString('pt-BR');
  };

  const getProviderIcon = (provider) => {
    switch (provider) {
      case 'gdrive':
        return (
          <svg className="w-6 h-6" viewBox="0 0 24 24">
            <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
            <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
            <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
            <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
          </svg>
        );
      case 'proton':
        return (
          <svg className="w-6 h-6" viewBox="0 0 24 24">
            <path fill="#6d4aff" d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
          </svg>
        );
      default:
        return <div className="w-6 h-6 bg-gray-300 rounded"></div>;
    }
  };

  const getProviderName = (provider) => {
    switch (provider) {
      case 'gdrive': return 'Google Drive';
      case 'proton': return 'Proton Drive';
      default: return provider;
    }
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-32 w-32 border-b-2 border-blue-500"></div>
          <p className="mt-4 text-gray-600">Carregando...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <img 
                src="https://avatars.githubusercontent.com/in/1201222?s=120&u=2686cf91179bbafbc7a71bfbc43004cf9ae1acea&v=4" 
                alt="Logo" 
                className="h-8 w-8 rounded"
              />
              <h1 className="ml-3 text-xl font-semibold text-gray-900">Sistema Multicloud</h1>
            </div>
            <div className="flex items-center space-x-4">
              <span className="text-gray-700">Olá, {user?.full_name || user?.username}</span>
              <button
                onClick={logout}
                className="bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded text-sm"
              >
                Sair
              </button>
            </div>
          </div>
        </div>
      </nav>

      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="mb-8">
            <h2 className="text-2xl font-bold text-gray-900 mb-2">Dashboard</h2>
            <p className="text-gray-600">Gerencie suas conexões multicloud</p>
          </div>

          {/* User Info Card */}
          <div className="bg-white overflow-hidden shadow rounded-lg mb-6">
            <div className="px-4 py-5 sm:p-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900">Informações da Conta</h3>
              <div className="mt-5 grid grid-cols-1 gap-5 sm:grid-cols-2">
                <div>
                  <dt className="text-sm font-medium text-gray-500">Usuário</dt>
                  <dd className="mt-1 text-sm text-gray-900">{user?.username}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">Email</dt>
                  <dd className="mt-1 text-sm text-gray-900">{user?.email}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">Nome Completo</dt>
                  <dd className="mt-1 text-sm text-gray-900">{user?.full_name || 'Não informado'}</dd>
                </div>
                <div>
                  <dt className="text-sm font-medium text-gray-500">Último Login</dt>
                  <dd className="mt-1 text-sm text-gray-900">{formatDate(user?.last_login)}</dd>
                </div>
              </div>
            </div>
          </div>

          {/* OAuth Providers */}
          <div className="bg-white overflow-hidden shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">Provedores Multicloud</h3>
              <div className="space-y-4">
                {Object.entries(oauthStatus).map(([provider, status]) => (
                  <div key={provider} className="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                    <div className="flex items-center space-x-3">
                      {getProviderIcon(provider)}
                      <div>
                        <h4 className="text-sm font-medium text-gray-900">{getProviderName(provider)}</h4>
                        <p className="text-sm text-gray-500">
                          Status: {status.connected ? (
                            <span className="text-green-600 font-medium">Conectado</span>
                          ) : (
                            <span className="text-red-600 font-medium">Desconectado</span>
                          )}
                        </p>
                        {status.connected && status.expires_at && (
                          <p className="text-xs text-gray-400">
                            Expira em: {formatDate(status.expires_at)}
                          </p>
                        )}
                      </div>
                    </div>
                    <div>
                      {status.connected ? (
                        <button
                          onClick={() => handleDisconnectProvider(provider)}
                          className="bg-red-500 hover:bg-red-700 text-white font-bold py-2 px-4 rounded text-sm"
                        >
                          Desconectar
                        </button>
                      ) : (
                        <button
                          onClick={() => handleConnectProvider(provider)}
                          className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded text-sm"
                        >
                          Conectar
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>

          {/* Terabox Info */}
          <div className="mt-6 bg-white overflow-hidden shadow rounded-lg">
            <div className="px-4 py-5 sm:p-6">
              <h3 className="text-lg leading-6 font-medium text-gray-900 mb-4">Terabox</h3>
              <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                <div className="flex">
                  <div className="flex-shrink-0">
                    <svg className="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clipRule="evenodd" />
                    </svg>
                  </div>
                  <div className="ml-3">
                    <h3 className="text-sm font-medium text-yellow-800">Configuração Manual</h3>
                    <p className="mt-2 text-sm text-yellow-700">
                      Terabox usa autenticação básica. Configure as credenciais no arquivo .env do backend:
                      <br />
                      <code className="bg-yellow-100 px-1 py-0.5 rounded text-xs">TERABOX_USER</code> e{' '}
                      <code className="bg-yellow-100 px-1 py-0.5 rounded text-xs">TERABOX_PASS</code>
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;