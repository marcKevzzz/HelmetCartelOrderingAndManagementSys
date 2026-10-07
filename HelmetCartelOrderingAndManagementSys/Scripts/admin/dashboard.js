/**
 * Helmet Cartel Operations - Dashboard Scripts
 * Chart.js initializations & dashboard interactions
 */
document.addEventListener('DOMContentLoaded', function () {
  // 1. Sales Trend Chart
  const salesCanvas = document.getElementById('salesVelocityChart');
  if (salesCanvas && window.Chart) {
    try {
      const dayLabels = JSON.parse(salesCanvas.getAttribute('data-day-labels') || '[]');
      const dayData = JSON.parse(salesCanvas.getAttribute('data-day-values') || '[]');
      const weekLabels = JSON.parse(salesCanvas.getAttribute('data-week-labels') || salesCanvas.getAttribute('data-labels') || '[]');
      const weekData = JSON.parse(salesCanvas.getAttribute('data-week-values') || salesCanvas.getAttribute('data-values') || '[]');
      const monthLabels = JSON.parse(salesCanvas.getAttribute('data-month-labels') || '[]');
      const monthData = JSON.parse(salesCanvas.getAttribute('data-month-values') || '[]');

      const ctx = salesCanvas.getContext('2d');
      const gradient = ctx.createLinearGradient(0, 0, 0, 220);
      gradient.addColorStop(0, 'rgba(24, 24, 27, 0.15)');
      gradient.addColorStop(1, 'rgba(24, 24, 27, 0.00)');

      const velocityChart = new window.Chart(ctx, {
        type: 'line',
        data: {
          labels: weekLabels,
          datasets: [{
            label: 'Revenue (\u20B1)',
            data: weekData,
            borderColor: '#18181B',
            backgroundColor: gradient,
            borderWidth: 2,
            fill: true,
            tension: 0.35,
            pointBackgroundColor: '#18181B',
            pointBorderColor: '#FFFFFF',
            pointBorderWidth: 2,
            pointRadius: 4,
            pointHoverRadius: 6
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false },
            tooltip: {
              backgroundColor: '#18181B',
              titleColor: '#FFFFFF',
              bodyColor: '#FFFFFF',
              padding: 10,
              cornerRadius: 8,
              callbacks: {
                label: function (context) {
                  return '\u20B1' + Number(context.raw).toLocaleString('en-US', { minimumFractionDigits: 2 });
                }
              }
            }
          },
          scales: {
            x: {
              grid: { display: false },
              ticks: { font: { size: 11, family: 'system-ui' }, color: '#71717A' }
            },
            y: {
              beginAtZero: true,
              grid: { color: 'rgba(0, 0, 0, 0.05)' },
              ticks: {
                font: { size: 11, family: 'system-ui' },
                color: '#71717A',
                callback: function (value) {
                  if (value >= 1000) return '\u20B1' + (value / 1000) + 'k';
                  return '\u20B1' + value;
                }
              }
            }
          }
        }
      });

      // Timeframe buttons
      const subtitleEl = document.getElementById('velocityTimeframeSubtitle');
      const timeframeBtns = document.querySelectorAll('.admin-chart-header [data-timeframe]');
      timeframeBtns.forEach(btn => {
        btn.addEventListener('click', function () {
          const tf = this.getAttribute('data-timeframe');
          timeframeBtns.forEach(b => b.classList.remove('active'));
          this.classList.add('active');

          if (tf === 'day') {
            velocityChart.data.labels = dayLabels;
            velocityChart.data.datasets[0].data = dayData;
            if (subtitleEl) subtitleEl.textContent = "Today's hourly performance across online and POS transactions";
          } else if (tf === 'month') {
            velocityChart.data.labels = monthLabels;
            velocityChart.data.datasets[0].data = monthData;
            if (subtitleEl) subtitleEl.textContent = "30-day performance across online and POS transactions";
          } else {
            velocityChart.data.labels = weekLabels;
            velocityChart.data.datasets[0].data = weekData;
            if (subtitleEl) subtitleEl.textContent = "7-day performance across online and POS transactions";
          }
          velocityChart.update();
        });
      });
    } catch (e) {
      console.warn('Dashboard sales chart init error:', e);
    }
  }

  // 2. Brand Distribution Doughnut Chart
  const brandCanvas = document.getElementById('brandDistributionChart');
  if (brandCanvas && window.Chart) {
    try {
      const brandLabels = JSON.parse(brandCanvas.getAttribute('data-labels') || '[]');
      const brandData = JSON.parse(brandCanvas.getAttribute('data-values') || '[]');

      const ctxBrand = brandCanvas.getContext('2d');
      new window.Chart(ctxBrand, {
        type: 'doughnut',
        data: {
          labels: brandLabels,
          datasets: [{
            data: brandData,
            backgroundColor: [
              '#18181B', // AGV
              '#3F3F46', // Gille
              '#71717A', // HNJ
              '#A1A1AA', // Shoei
              '#D4D4D8'  // Zebra
            ],
            borderWidth: 2,
            borderColor: '#FFFFFF',
            hoverOffset: 4
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          cutout: '70%',
          plugins: {
            legend: {
              position: 'bottom',
              labels: {
                boxWidth: 12,
                boxHeight: 12,
                padding: 14,
                font: { size: 11, family: 'system-ui' },
                color: '#27272A'
              }
            },
            tooltip: {
              backgroundColor: '#18181B',
              titleColor: '#FFFFFF',
              bodyColor: '#FFFFFF',
              padding: 10,
              cornerRadius: 8,
              callbacks: {
                label: function (context) {
                  return ' ' + context.label + ': ' + context.raw + ' units';
                }
              }
            }
          }
        }
      });
    } catch (e) {
      console.warn('Dashboard brand chart init error:', e);
    }
  }

  // 3. Recent Activity Feed - Dynamic Load More & Role Badge
  const btnLoadMore = document.getElementById('btnLoadMoreActivities');
  const activityList = document.querySelector('.admin-activity-list');
  if (btnLoadMore && activityList) {
    let currentOffset = activityList.querySelectorAll('.admin-activity-item').length;
    const pageSize = 8;

    const escapeHtml = (text) => {
      if (!text) return '';
      const div = document.createElement('div');
      div.textContent = text;
      return div.innerHTML;
    };

    const formatDetail = (detail) => {
      if (!detail) return '';
      return escapeHtml(detail)
        .replace(/PHP /g, '&#8369;')
        .replace(/â€¢/g, '&bull;')
        .replace(/•/g, '&bull;')
        .replace(/&amp;bull;/g, '&bull;');
    };

    const formatTime = (dateStr) => {
      if (!dateStr) return '';
      try {
        const d = new Date(dateStr);
        if (isNaN(d.getTime())) return '';
        const now = new Date();
        const diffMs = Math.max(0, now.getTime() - d.getTime());
        const diffSec = Math.floor(diffMs / 1000);
        const diffMin = Math.floor(diffSec / 60);
        const diffHour = Math.floor(diffMin / 60);
        const diffDay = Math.floor(diffHour / 24);

        let relative = 'just now';
        if (diffMin >= 1 && diffMin < 60) {
          relative = `${diffMin}m ago`;
        } else if (diffHour >= 1 && diffHour < 24) {
          relative = `${diffHour}h ago`;
        } else if (diffDay >= 1) {
          relative = `${diffDay}d ago`;
        }

        const dateFormatted = d.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        const timeFormatted = d.toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit', hour12: true });
        return `${relative} &middot; ${dateFormatted}, ${timeFormatted}`;
      } catch (_) {
        return '';
      }
    };

    const getActivityIconMarkup = (type) => {
      type = (type || '').toLowerCase();
      if (type.includes('stock') || type.includes('inventory')) {
        return '<path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>' +
               '<polyline points="3.27 6.96 12 12.01 20.73 6.96"></polyline>' +
               '<line x1="12" y1="22.08" x2="12" y2="12"></line>';
      }
      if (type.includes('order')) {
        return '<path d="M6 2L3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z"></path>' +
               '<line x1="3" y1="6" x2="21" y2="6"></line>' +
               '<path d="M16 10a4 4 0 0 1-8 0"></path>';
      }
      if (type.includes('rma') || type.includes('return') || type.includes('exchange')) {
        return '<polyline points="1 4 1 10 7 10"></polyline>' +
               '<polyline points="23 20 23 14 17 14"></polyline>' +
               '<path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4l-4.64 4.36A9 9 0 0 1 3.51 15"></path>';
      }
      if (type.includes('review') || type.includes('rating')) {
        return '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"></polygon>';
      }
      if (type.includes('payment') || type.includes('refund')) {
        return '<rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect>' +
               '<line x1="1" y1="10" x2="23" y2="10"></line>';
      }
      return '<polygon points="12 2 2 7 12 12 22 7 12 2"></polygon>' +
             '<polyline points="2 17 12 22 22 17"></polyline>' +
             '<polyline points="2 12 12 17 22 12"></polyline>';
    };

    const getActivityInspectUrl = (type, ref) => {
      type = (type || '').toLowerCase();
      const refEnc = encodeURIComponent(ref || '');
      const refUpper = (ref || '').toUpperCase();

      if (type.includes('stock') || type.includes('inventory')) {
        if (!ref) return '/Pages/Admin/Inventory/Inventory.aspx';
        if (refUpper.startsWith('PO-') || refUpper.includes('RESTOCK')) {
          return `/Pages/Admin/Inventory/Inventory.aspx?view=audit&search=${refEnc}`;
        }
        return `/Pages/Admin/Inventory/Inventory.aspx?search=${refEnc}`;
      }
      if (type.includes('payment')) {
        return ref ? `/Pages/Admin/Orders/OrderDetail.aspx?paymentRef=${refEnc}` : '/Pages/Admin/Orders/Orders.aspx';
      }
      if (type.includes('order')) {
        return ref ? `/Pages/Admin/Orders/OrderDetail.aspx?orderNumber=${refEnc}` : '/Pages/Admin/Orders/Orders.aspx';
      }
      if (type.includes('rma') || type.includes('return') || type.includes('exchange')) {
        return ref ? `/Pages/Admin/Returns/Returns.aspx?search=${refEnc}` : '/Pages/Admin/Returns/Returns.aspx';
      }
      if (type.includes('review') || type.includes('rating')) {
        const match = (ref || '').match(/\d+/);
        return match ? `/Pages/Admin/Reviews/Reviews.aspx?reviewId=${match[0]}` : '/Pages/Admin/Reviews/Reviews.aspx';
      }
      return ref ? `/Pages/Admin/Orders/Orders.aspx?search=${refEnc}` : '/Pages/Admin/Orders/Orders.aspx';
    };

    btnLoadMore.addEventListener('click', async function () {
      if (btnLoadMore.disabled) return;
      btnLoadMore.disabled = true;
      const originalText = btnLoadMore.innerHTML;
      btnLoadMore.innerHTML = `
        <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="admin-spin-icon">
          <line x1="12" y1="2" x2="12" y2="6"></line>
          <line x1="12" y1="18" x2="12" y2="22"></line>
          <line x1="4.93" y1="4.93" x2="7.76" y2="7.76"></line>
          <line x1="16.24" y1="16.24" x2="19.07" y2="19.07"></line>
          <line x1="2" y1="12" x2="6" y2="12"></line>
          <line x1="18" y1="12" x2="22" y2="12"></line>
          <line x1="4.93" y1="19.07" x2="7.76" y2="16.24"></line>
          <line x1="16.24" y1="7.76" x2="19.07" y2="4.93"></line>
        </svg>
        <span>Loading activities...</span>
      `;

      try {
        const response = await fetch(`/api/v1/admin/dashboard/activity?limit=${pageSize}&offset=${currentOffset}`);
        if (!response.ok) {
          throw new Error('Failed to load activities');
        }
        const json = await response.json();
        const items = json?.data || json?.Data || [];

        if (!Array.isArray(items) || items.length === 0) {
          btnLoadMore.innerHTML = '<span>No More Activities</span>';
          btnLoadMore.disabled = true;
          return;
        }

        const fragment = document.createDocumentFragment();
        items.forEach(item => {
          const li = document.createElement('li');
          li.className = 'admin-activity-item';
          const roleClass = (item.actorRole || 'customer').toLowerCase();
          const roleLabel = item.actorRole || 'Customer';

          li.innerHTML = `
            <div class="admin-activity-rail" aria-hidden="true">
              <span class="admin-activity-icon">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  ${getActivityIconMarkup(item.activityType)}
                </svg>
              </span>
            </div>
            <div class="admin-activity-content">
              <div class="admin-activity-heading">
                <div class="admin-activity-heading-left">
                  <span class="admin-activity-actor">${escapeHtml(item.actor)}</span>
                  <span class="admin-activity-role-badge admin-activity-role-badge--${roleClass}">${escapeHtml(roleLabel)}</span>
                  <span class="admin-activity-type">${escapeHtml(item.activityType)}</span>
                </div>
                <span class="admin-activity-time">${formatTime(item.createdAt)}</span>
              </div>
              <div class="admin-activity-detail-card">
                <div class="admin-activity-detail-body">
                  <span class="admin-activity-ref">${escapeHtml(item.reference)}</span>
                  <span class="admin-activity-detail">${formatDetail(item.detail)}</span>
                </div>
                <a href="${getActivityInspectUrl(item.activityType, item.reference)}" class="admin-activity-inspect-btn" title="Inspect details in management console">
                  <span>Inspect</span>
                  <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9 18 15 12 9 6"></polyline></svg>
                </a>
              </div>
            </div>
          `;
          fragment.appendChild(li);
        });

        activityList.appendChild(fragment);
        currentOffset += items.length;

        if (items.length < pageSize) {
          btnLoadMore.innerHTML = '<span>No More Activities</span>';
          btnLoadMore.disabled = true;
        } else {
          btnLoadMore.innerHTML = originalText;
          btnLoadMore.disabled = false;
        }
      } catch (err) {
        console.error('Error loading more activities:', err);
        btnLoadMore.innerHTML = originalText;
        btnLoadMore.disabled = false;
        if (window.showAdminToast) {
          window.showAdminToast('Could not load more activities. Please try again.', 'error');
        }
      }
    });
  }
});
