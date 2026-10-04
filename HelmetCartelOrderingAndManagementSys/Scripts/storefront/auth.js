/**
 * HELMET CARTEL - FULL-SCREEN AUTHENTICATION SCRIPT
 * Manages Sign In and Sign Up interactions, validation, JWT storage,
 * and seamless redirection without floating card modals.
 */

import { APP_CONSTANTS } from '../constants.js';

document.addEventListener('DOMContentLoaded', () => {
  // Elements
  const tabSignin = document.getElementById('tab-signin');
  const tabSignup = document.getElementById('tab-signup');
  const formSignin = document.getElementById('form-signin');
  const formSignup = document.getElementById('form-signup');
  const authAlert = document.getElementById('auth-alert');
  const alertText = document.getElementById('auth-alert-text');

  // Input Fields - Sign In
  const signinEmail = document.getElementById('signin-email');
  const signinPassword = document.getElementById('signin-password');
  const btnSigninSubmit = document.getElementById('btn-signin-submit');

  // Input Fields - Sign Up
  const signupFirstName = document.getElementById('signup-firstname');
  const signupLastName = document.getElementById('signup-lastname');
  const signupEmail = document.getElementById('signup-email');
  const signupPhone = document.getElementById('signup-phone');
  const signupPassword = document.getElementById('signup-password');
  const signupPasswordConfirm = document.getElementById('signup-password-confirm');
  const btnSignupSubmit = document.getElementById('btn-signup-submit');

  // Password Visibility Toggles
  document.querySelectorAll('.auth-toggle-pwd').forEach(button => {
    button.addEventListener('click', (e) => {
      e.preventDefault();
      const input = button.closest('.auth-input-container').querySelector('input');
      if (input.type === 'password') {
        input.type = 'text';
        button.setAttribute('aria-label', 'Hide password');
      } else {
        input.type = 'password';
        button.setAttribute('aria-label', 'Show password');
      }
    });
  });

  // Mode Switcher Functions
  function setMode(mode) {
    clearAlert();
    tabSignin.setAttribute('aria-selected', String(mode !== 'signup'));
    tabSignup.setAttribute('aria-selected', String(mode === 'signup'));
    if (mode === 'signup') {
      tabSignup.classList.add('auth-mode-btn--active');
      tabSignin.classList.remove('auth-mode-btn--active');
      formSignup.classList.remove('auth-form-hidden');
      formSignin.classList.add('auth-form-hidden');
      if (signupFirstName) signupFirstName.focus();
    } else {
      tabSignin.classList.add('auth-mode-btn--active');
      tabSignup.classList.remove('auth-mode-btn--active');
      formSignin.classList.remove('auth-form-hidden');
      formSignup.classList.add('auth-form-hidden');
      if (signinEmail) signinEmail.focus();
    }
  }

  if (tabSignin && tabSignup) {
    tabSignin.addEventListener('click', () => setMode('signin'));
    tabSignup.addEventListener('click', () => setMode('signup'));
  }

  // Check URL query parameters for mode and session status
  const urlParams = new URLSearchParams(window.location.search);
  const initialMode = urlParams.get('mode');
  if (initialMode === 'signup') {
    setMode('signup');
  }

  if (urlParams.get('logout') === '1') {
    showAlert('You have been signed out successfully.', 'success');
  } else if (urlParams.get('sessionExpired') === '1') {
    localStorage.removeItem('hc_auth_token');
    localStorage.removeItem('hc_user_profile');
    showAlert('Your session has expired. Please sign in again to continue.', 'error');
  } else if (urlParams.get('authRequired') === '1') {
    showAlert('Please sign in to access your profile, track your orders, and view receipts.', 'info');
  }

  // Alert Helpers
  function showAlert(message, type = 'error') {
    if (!authAlert || !alertText) return;
    alertText.textContent = message;
    authAlert.className = `auth-alert auth-alert--visible auth-alert--${type}`;
  }

  function clearAlert() {
    if (!authAlert) return;
    authAlert.className = 'auth-alert';
  }

  // Inline Field Error Management
  function setFieldError(fieldId, errorMsg) {
    const input = document.getElementById(fieldId);
    const errSpan = document.getElementById(`err-${fieldId}`);
    if (input) {
      if (errorMsg) {
        input.classList.add('is-invalid');
        input.setAttribute('aria-invalid', 'true');
      } else {
        input.classList.remove('is-invalid');
        input.removeAttribute('aria-invalid');
      }
    }
    if (errSpan) {
      errSpan.textContent = errorMsg || '';
      errSpan.classList.toggle('has-error', !!errorMsg);
    }
  }

  function clearAllErrors() {
    clearAlert();
    [
      'signin-email', 'signin-password',
      'signup-firstname', 'signup-lastname', 'signup-email', 'signup-phone', 'signup-password', 'signup-password-confirm'
    ].forEach(id => setFieldError(id, ''));
  }

  function validateEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  // Real-time error clearing on input and blur validation
  [
    { id: 'signin-email', required: true, isEmail: true },
    { id: 'signin-password', required: true },
    { id: 'signup-firstname', required: true },
    { id: 'signup-lastname', required: true },
    { id: 'signup-email', required: true, isEmail: true },
    { id: 'signup-password', required: true, minLength: 6 },
    { id: 'signup-password-confirm', required: true, matchWith: 'signup-password' },
    { id: 'signup-phone', required: true, isPhone: true }
  ].forEach(rule => {
    const el = document.getElementById(rule.id);
    if (!el) return;
    el.addEventListener('input', () => {
      if (el.classList.contains('is-invalid')) {
        setFieldError(rule.id, '');
      }
    });
    el.addEventListener('blur', () => {
      const val = el.value.trim();
      if (rule.required && !val) {
        setFieldError(rule.id, 'This field is required.');
      } else if (rule.isEmail && val && !validateEmail(val)) {
        setFieldError(rule.id, 'Please enter a valid email address.');
      } else if (rule.isPhone && val && !/^(\+?63|0)9\d{9}$/.test(val.replace(/[\s-]/g, ''))) {
        setFieldError(rule.id, 'Enter a valid Philippine mobile number (e.g. 0917-123-4567).');
      } else if (rule.minLength && val && val.length < rule.minLength) {
        setFieldError(rule.id, `Must be at least ${rule.minLength} characters.`);
      } else if (rule.matchWith) {
        const otherVal = document.getElementById(rule.matchWith)?.value || '';
        if (val && val !== otherVal) {
          setFieldError(rule.id, 'Passwords do not match.');
        }
      }
    });
  });

  // Handle Sign In Submission
  if (formSignin) {
    formSignin.addEventListener('submit', async (e) => {
      e.preventDefault();
      clearAlert();

      const email = signinEmail.value.trim();
      const password = signinPassword.value;

      let hasError = false;
      if (!email) {
        setFieldError('signin-email', 'Email address is required.');
        hasError = true;
      } else if (!validateEmail(email)) {
        setFieldError('signin-email', 'Please enter a valid email address.');
        hasError = true;
      } else {
        setFieldError('signin-email', '');
      }

      if (!password) {
        setFieldError('signin-password', 'Password is required.');
        hasError = true;
      } else {
        setFieldError('signin-password', '');
      }

      if (hasError) {
        showAlert('Please resolve the errors highlighted below.');
        return;
      }

      setLoading(btnSigninSubmit, true);

      try {
        const response = await fetch('/api/v1/auth/login', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({ email, password, rememberMe: document.getElementById('signin-remember')?.checked === true })
        });

        const result = await response.json();

        const isSuccess = result && (result.success === true || result.Success === true);
        const data = result ? (result.data || result.Data) : null;

        if (isSuccess && data) {
          const token = data.token || data.Token;
          const user = data.user || data.User;
          if (token) localStorage.setItem('hc_auth_token', token);
          if (user) localStorage.setItem('hc_user_profile', JSON.stringify(user));

          const loginRole = user ? (user.role || user.Role) : null;
          if (loginRole === APP_CONSTANTS.ROLES.ADMIN || loginRole === APP_CONSTANTS.ROLES.STAFF) {
            sessionStorage.setItem(APP_CONSTANTS.STORAGE_KEYS.ADMIN_LOGIN_SUCCESS, '1');
          } else {
            const firstName = user?.firstName || user?.FirstName || 'Rider';
            sessionStorage.setItem('hc_login_toast', `Welcome back, ${firstName}! You have signed in successfully.`);
          }

          showAlert('Authentication verified. Redirecting...', 'success');

          setTimeout(() => {
            const role = user ? (user.role || user.Role) : null;
            const isAdminOrStaff = role === 'Admin' || role === 'Staff' || role === APP_CONSTANTS.ROLES.ADMIN || role === APP_CONSTANTS.ROLES.STAFF;
            const returnUrl = urlParams.get('returnUrl');

            if (isAdminOrStaff) {
              // Admin/Staff users must always be routed to the Admin panel (unless returnUrl is already within Admin area)
              if (returnUrl && returnUrl.toLowerCase().includes('/admin/')) {
                window.location.href = returnUrl;
              } else {
                window.location.href = APP_CONSTANTS.ROUTES.ADMIN_DASHBOARD;
              }
              return;
            }

            // Customer users redirect to requested returnUrl or Default page
            if (returnUrl) {
              window.location.href = returnUrl;
              return;
            }

            window.location.href = APP_CONSTANTS.ROUTES.HOME;
          }, 800);
        } else {
          const msg = (result ? (result.message || result.Message) : null) || 'Invalid email or password.';
          showAlert(msg);
          setFieldError('signin-email', 'Check email credentials');
          setFieldError('signin-password', 'Check password credentials');
          setLoading(btnSigninSubmit, false);
        }
      } catch (err) {
        console.error('Sign In error:', err);
        showAlert('Connection error. Please try again.');
        setLoading(btnSigninSubmit, false);
      }
    });
  }

  // Handle Sign Up Submission
  if (formSignup) {
    formSignup.addEventListener('submit', async (e) => {
      e.preventDefault();
      clearAlert();

      const firstName = signupFirstName.value.trim();
      const lastName = signupLastName.value.trim();
      const email = signupEmail.value.trim();
      const phone = signupPhone.value.trim();
      const password = signupPassword.value;
      const confirm = signupPasswordConfirm.value;

      let hasError = false;

      if (!firstName) {
        setFieldError('signup-firstname', 'First name is required.');
        hasError = true;
      } else {
        setFieldError('signup-firstname', '');
      }
      if (!lastName) {
        setFieldError('signup-lastname', 'Last name is required.');
        hasError = true;
      } else {
        setFieldError('signup-lastname', '');
      }

      if (!email) {
        setFieldError('signup-email', 'Email Address is required.');
        hasError = true;
      } else if (!validateEmail(email)) {
        setFieldError('signup-email', 'Please enter a valid email address.');
        hasError = true;
      } else {
        setFieldError('signup-email', '');
      }

      if (!phone) {
        setFieldError('signup-phone', 'Mobile phone number is required.');
        hasError = true;
      } else if (!/^(\+?63|0)9\d{9}$/.test(phone.replace(/[\s-]/g, ''))) {
        setFieldError('signup-phone', 'Enter a valid Philippine mobile number (e.g. 0917-123-4567).');
        hasError = true;
      } else {
        setFieldError('signup-phone', '');
      }

      if (!password) {
        setFieldError('signup-password', 'Password is required.');
        hasError = true;
      } else if (password.length < 6) {
        setFieldError('signup-password', 'Password must be at least 6 characters.');
        hasError = true;
      } else {
        setFieldError('signup-password', '');
      }

      if (!confirm) {
        setFieldError('signup-password-confirm', 'Please confirm your password.');
        hasError = true;
      } else if (password !== confirm) {
        setFieldError('signup-password-confirm', 'Passwords do not match.');
        hasError = true;
      } else {
        setFieldError('signup-password-confirm', '');
      }

      if (hasError) {
        showAlert('Please resolve the errors highlighted below.');
        return;
      }

      setLoading(btnSignupSubmit, true);

      try {
        const response = await fetch('/api/v1/auth/register', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            firstName,
            lastName,
            email,
            password,
            phoneNumber: phone
          })
        });

        const result = await response.json();

        const isSuccess = result && (result.success === true || result.Success === true);
        const data = result ? (result.data || result.Data) : null;

        if (isSuccess && data) {
          const token = data.token || data.Token;
          const user = data.user || data.User;
          if (token) localStorage.setItem('hc_auth_token', token);
          if (user) localStorage.setItem('hc_user_profile', JSON.stringify(user));

          const firstName = user?.firstName || user?.FirstName || 'Rider';
          sessionStorage.setItem('hc_login_toast', `Welcome to Helmet Cartel, ${firstName}! Your account has been registered.`);

          showAlert('Account created successfully! Redirecting...', 'success');

          setTimeout(() => {
            const returnUrl = urlParams.get('returnUrl');
            if (returnUrl) {
              window.location.href = returnUrl;
            } else {
              window.location.href = APP_CONSTANTS.ROUTES.HOME;
            }
          }, 1000);
        } else {
          const msg = (result ? (result.message || result.Message) : null) || 'Failed to create account.';
          showAlert(msg);
          if (msg.toLowerCase().includes('email')) {
            setFieldError('signup-email', msg);
          } else if (msg.toLowerCase().includes('phone') || msg.toLowerCase().includes('mobile')) {
            setFieldError('signup-phone', msg);
          }
          setLoading(btnSignupSubmit, false);
        }
      } catch (err) {
        console.error('Sign Up error:', err);
        showAlert('Connection error. Please try again.');
        setLoading(btnSignupSubmit, false);
      }
    });
  }

  function setLoading(button, isLoading) {
    if (!button) return;
    if (isLoading) {
      button.disabled = true;
      button.classList.add('auth-submit-btn--loading');
    } else {
      button.disabled = false;
      button.classList.remove('auth-submit-btn--loading');
    }
  }
});
