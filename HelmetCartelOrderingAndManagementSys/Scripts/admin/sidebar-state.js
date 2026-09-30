(() => {
  try {
    const collapseKey = 'hc_admin_sidebar_collapsed';
    const isDesktop = window.matchMedia('(min-width: 1025px)').matches;

    if (isDesktop && window.localStorage.getItem(collapseKey) === 'true') {
      document.documentElement.classList.add('admin-sidebar-collapsed');
    }
  } catch (error) {
    // Keep the default expanded layout when storage is unavailable.
  }
})();
