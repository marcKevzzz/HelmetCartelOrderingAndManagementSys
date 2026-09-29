/**
 * Helmet Cartel - Admin Search History Component
 * Manages localStorage-based search history for #adminGlobalSearch.
 * Displays recent searches on focus, allows removing individual items,
 * provides clear-all functionality, sanitizes queries, and prevents storing sensitive data.
 */

(function () {
  'use strict';

  const STORAGE_KEY = 'hc_admin_search_history';
  const MAX_HISTORY_ITEMS = 8;
  const MAX_QUERY_LENGTH = 60;

  // Sensitive patterns to avoid storing (passwords, tokens, credit cards)
  const SENSITIVE_PATTERNS = [
    /ey[A-Za-z0-9_-]{10,}/i,               // JWT / base64 tokens
    /\b(?:pass(?:word)?|secret|token|key|bearer)\b/i, // auth keywords
    /\b(?:\d[ -]*?){13,16}\b/,             // Credit card numbers
    /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/ // Raw emails
  ];

  function isSensitive(query) {
    if (!query) return true;
    return SENSITIVE_PATTERNS.some(regex => regex.test(query));
  }

  function getHistory() {
    try {
      const data = localStorage.getItem(STORAGE_KEY);
      if (!data) return [];
      const parsed = JSON.parse(data);
      return Array.isArray(parsed) ? parsed : [];
    } catch (e) {
      console.warn('Failed to read search history:', e);
      return [];
    }
  }

  function saveHistory(list) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(list.slice(0, MAX_HISTORY_ITEMS)));
    } catch (e) {
      console.warn('Failed to save search history:', e);
    }
  }

  function addSearchItem(rawQuery) {
    const query = (rawQuery || '').trim();
    if (!query || query.length < 2 || query.length > MAX_QUERY_LENGTH) return;
    if (isSensitive(query)) return;

    let history = getHistory();
    // Remove if already exists to push to the top
    history = history.filter(item => item.toLowerCase() !== query.toLowerCase());
    history.unshift(query);
    saveHistory(history);
  }

  function removeSearchItem(queryToRemove) {
    let history = getHistory();
    history = history.filter(item => item.toLowerCase() !== queryToRemove.toLowerCase());
    saveHistory(history);
  }

  function clearAllHistory() {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch (e) {}
  }

  function escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function renderSearchHistory(dropdown, searchInput) {
    const history = getHistory();
    if (!history || history.length === 0) {
      dropdown.style.display = 'none';
      dropdown.innerHTML = '';
      return;
    }

    let html = `
      <div class="admin-search-history-container" role="region" aria-label="Recent Searches">
        <div class="admin-search-history-header">
          <span class="admin-search-history-title">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <circle cx="12" cy="12" r="10"></circle>
              <polyline points="12 6 12 12 16 14"></polyline>
            </svg>
            Recent Searches
          </span>
          <button type="button" class="admin-search-history-clear-btn" id="adminClearSearchHistory" title="Clear all recent searches">
            Clear All
          </button>
        </div>
        <ul class="admin-search-history-list" role="listbox">
    `;

    history.forEach((term, index) => {
      html += `
        <li class="admin-search-history-item" role="option" data-term="${escapeHtml(term)}">
          <button type="button" class="admin-search-history-term-btn" title="Search for '${escapeHtml(term)}'">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-search-history-icon" aria-hidden="true">
              <circle cx="11" cy="11" r="8"></circle>
              <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
            </svg>
            <span class="admin-search-history-text">${escapeHtml(term)}</span>
          </button>
          <button type="button" class="admin-search-history-remove-btn" data-remove-term="${escapeHtml(term)}" aria-label="Remove '${escapeHtml(term)}' from history" title="Remove from history">
            <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
              <line x1="18" y1="6" x2="6" y2="18"></line>
              <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
          </button>
        </li>
      `;
    });

    html += `
        </ul>
      </div>
    `;

    dropdown.innerHTML = html;
    dropdown.classList.remove('is-hidden');
    dropdown.removeAttribute('hidden');
    dropdown.style.display = 'block';

    // Bind item click listeners
    const clearBtn = dropdown.querySelector('#adminClearSearchHistory');
    if (clearBtn) {
      clearBtn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        clearAllHistory();
        dropdown.style.display = 'none';
        dropdown.innerHTML = '';
        searchInput.focus();
      });
    }

    dropdown.querySelectorAll('.admin-search-history-remove-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        const term = btn.getAttribute('data-remove-term');
        if (term) {
          removeSearchItem(term);
          renderSearchHistory(dropdown, searchInput);
        }
      });
    });

    dropdown.querySelectorAll('.admin-search-history-term-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        const item = btn.closest('.admin-search-history-item');
        const term = item ? item.getAttribute('data-term') : '';
        if (term) {
          searchInput.value = term;
          addSearchItem(term);
          // Dispatch input event to trigger search
          searchInput.dispatchEvent(new Event('input', { bubbles: true }));
          searchInput.focus();
        }
      });
    });
  }

  // Initialize Search History integration with #adminGlobalSearch
  document.addEventListener('DOMContentLoaded', () => {
    const searchInput = document.getElementById('adminGlobalSearch');
    const searchDropdown = document.getElementById('adminSearchDropdown');

    if (!searchInput || !searchDropdown) return;

    // Show recent searches on focus if empty
    searchInput.addEventListener('focus', () => {
      if (!searchInput.value.trim()) {
        renderSearchHistory(searchDropdown, searchInput);
      }
    });

    // Save search query on Enter keypress
    searchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        const val = searchInput.value.trim();
        if (val) {
          addSearchItem(val);
        }
      }
    });

    // When typing, if input becomes empty, show history again
    searchInput.addEventListener('input', () => {
      if (!searchInput.value.trim()) {
        renderSearchHistory(searchDropdown, searchInput);
      }
    });

    // Hide dropdown on Escape
    searchInput.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        searchDropdown.style.display = 'none';
      }
    });
  });

  // Export functions to window namespace for testing & interoperability
  window.AdminSearchHistory = {
    add: addSearchItem,
    remove: removeSearchItem,
    clear: clearAllHistory,
    get: getHistory
  };
})();
