// Make the global toast entry point available before Web Forms startup scripts run.
window.__adminToastQueue = window.__adminToastQueue || [];
if (typeof window.showAdminToast !== 'function') {
  window.showAdminToast = function () {
    window.__adminToastQueue.push(Array.prototype.slice.call(arguments));
  };
}
