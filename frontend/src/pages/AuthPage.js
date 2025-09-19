import React, { useState } from 'react';
import LoginForm from '../components/auth/LoginForm';
import SignupForm from '../components/auth/SignupForm';

const AuthPage = () => {
  const [isLogin, setIsLogin] = useState(true);

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8">
      <div className="sm:mx-auto sm:w-full sm:max-w-md">
        <div className="flex justify-center">
          <img 
            src="https://avatars.githubusercontent.com/in/1201222?s=120&u=2686cf91179bbafbc7a71bfbc43004cf9ae1acea&v=4" 
            alt="Logo" 
            className="h-16 w-16 rounded-lg"
          />
        </div>
        <h1 className="mt-6 text-center text-3xl font-bold text-gray-900">
          Sistema Multicloud
        </h1>
        <p className="mt-2 text-center text-sm text-gray-600">
          {isLogin ? 'Entre na sua conta' : 'Crie sua conta'}
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        {isLogin ? (
          <LoginForm onSwitchToSignup={() => setIsLogin(false)} />
        ) : (
          <SignupForm onSwitchToLogin={() => setIsLogin(true)} />
        )}
      </div>

      <div className="mt-8 text-center">
        <p className="text-xs text-gray-500">
          Sistema integrado com GDrive • Terabox • Proton
        </p>
      </div>
    </div>
  );
};

export default AuthPage;