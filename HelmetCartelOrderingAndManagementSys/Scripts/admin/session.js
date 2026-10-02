import { APP_CONSTANTS } from '../constants.js';

// JWT expiry is enforced by C#; this keeps an already-open admin page in sync.
let expiryTimer;
let redirecting = false;
function expireSession() {
  if (redirecting) return;
  redirecting = true;
  localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN);
  localStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.USER_PROFILE);
  const returnUrl = window.location.pathname + window.location.search;
  window.location.replace(`${APP_CONSTANTS.ROUTES.AUTH}?sessionExpired=1&returnUrl=${encodeURIComponent(returnUrl)}`);
}
function checkExpiry() {
  clearTimeout(expiryTimer);
  try {
    const token = localStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN);
    const encoded = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const payload = JSON.parse(atob(encoded.padEnd(Math.ceil(encoded.length / 4) * 4, '=')));
    const remaining = Number(payload.exp) * 1000 - Date.now();
    if (!Number.isFinite(remaining) || remaining <= 0) return expireSession();
    expiryTimer = setTimeout(checkExpiry, Math.min(remaining, 2147483647));
  } catch { expireSession(); }
}
const originalFetch = window.fetch.bind(window);
window.fetch = async (...args) => {
  const response = await originalFetch(...args);
  const requestUrl = new URL(args[0] instanceof Request ? args[0].url : args[0], window.location.href);
  if (response.status === 401 && requestUrl.origin === window.location.origin && requestUrl.pathname.startsWith(APP_CONSTANTS.API_BASE_URL + '/')) expireSession();
  return response;
};
window.addEventListener('focus', checkExpiry);
window.addEventListener('pageshow', checkExpiry);
window.addEventListener('storage', event => {
  if (event.key === APP_CONSTANTS.STORAGE_KEYS.AUTH_TOKEN || event.key === null) checkExpiry();
});
document.addEventListener('visibilitychange', () => { if (!document.hidden) checkExpiry(); });
checkExpiry();
if (!redirecting && sessionStorage.getItem(APP_CONSTANTS.STORAGE_KEYS.ADMIN_LOGIN_SUCCESS) === '1') {
  sessionStorage.removeItem(APP_CONSTANTS.STORAGE_KEYS.ADMIN_LOGIN_SUCCESS);
  window.showAdminToast('You have signed in successfully.', 'success', 'Welcome Back');
}
