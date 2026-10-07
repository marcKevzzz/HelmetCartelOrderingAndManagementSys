/**
 * Helmet Cartel Operations - Reports & Analytics Scripts
 * Top 5 Sales Performance - Razor-Sharp Monochrome Vector Graph with Dimension & Metric Filters
 */
document.addEventListener('DOMContentLoaded', function () {
  // Brand inventory toggle
  document.querySelectorAll('.js-brand-inventory-toggle').forEach(button => {
    button.addEventListener('click', () => {
      const details = document.getElementById(button.getAttribute('aria-controls'));
      if (!details) return;
      const open = button.getAttribute('aria-expanded') !== 'true';
      button.setAttribute('aria-expanded', String(open));
      button.setAttribute('aria-label', open ? 'Hide low-stock items' : 'Show low-stock items');
      details.hidden = !open;
    });
  });

  // Target container for Top 5 graph
  const container = document.getElementById('top5GraphContainer') ||
                    document.getElementById('perfChartWrapper') ||
                    document.getElementById('performanceListContainer');
  if (!container) return;

  let rawItems = [];
  try {
    const rawData = container.getAttribute('data-items');
    rawItems = JSON.parse(rawData || '[]');
  } catch (e) {
    console.warn('Error parsing sales performance items:', e);
    rawItems = [];
  }

  // Filter State (Fixed to strictly Top 5, interactive Dimension & Metric)
  const state = {
    viewBy: 'item',     // 'item', 'brand', 'category'
    metric: 'units',    // 'units', 'revenue', 'orders'
    topN: 5             // Strictly Top 5
  };

  // Wire Tab Event Listeners
  document.querySelectorAll('#viewByTabs button').forEach(btn => {
    btn.addEventListener('click', function () {
      document.querySelectorAll('#viewByTabs button').forEach(b => b.classList.remove('active'));
      this.classList.add('active');
      state.viewBy = this.getAttribute('data-view') || 'item';
      renderGraph();
    });
  });

  document.querySelectorAll('#metricTabs button').forEach(btn => {
    btn.addEventListener('click', function () {
      document.querySelectorAll('#metricTabs button').forEach(b => b.classList.remove('active'));
      this.classList.add('active');
      state.metric = this.getAttribute('data-metric') || 'units';
      renderGraph();
    });
  });

  function formatDisplayVal(val, metric) {
    if (metric === 'revenue') {
      if (val >= 1000000) {
        return '\u20B1' + (val / 1000000).toFixed(1) + 'M';
      }
      if (val >= 1000) {
        const k = val / 1000;
        return '\u20B1' + (k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)) + 'k';
      }
      return '\u20B1' + Number(val).toLocaleString('en-US', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
    }
    if (val >= 1000) {
      const k = val / 1000;
      return (k % 1 === 0 ? k.toFixed(0) : k.toFixed(1)) + 'k';
    }
    return Number(val).toLocaleString();
  }

  function formatTickVal(val, metric) {
    if (metric === 'revenue') {
      if (val >= 1000000) return '\u20B1' + (val / 1000000) + 'M';
      if (val >= 1000) return '\u20B1' + (val / 1000) + 'k';
      return '\u20B1' + val;
    }
    if (val >= 1000) return (val / 1000) + 'k';
    return String(val);
  }

  function renderGraph() {
    // 1. Group items based on viewBy
    let groups = [];
    if (state.viewBy === 'item') {
      groups = rawItems.map(item => ({
        title: item.ProductName || item.productName || 'Unknown Product',
        brand: item.BrandName || item.brandName || '',
        category: item.CategoryName || item.categoryName || '',
        units: Number(item.UnitsSold || item.unitsSold || 0),
        orders: Number(item.OrderCount || item.orderCount || 0),
        revenue: Number(item.Revenue || item.revenue || 0),
        avgPrice: Number(item.AverageSellingPrice || item.averageSellingPrice || 0)
      }));
    } else if (state.viewBy === 'brand') {
      const brandMap = new Map();
      rawItems.forEach(item => {
        const key = item.BrandName || item.brandName || 'Unknown Brand';
        if (!brandMap.has(key)) {
          brandMap.set(key, { title: key, brand: key, category: '', units: 0, orders: 0, revenue: 0 });
        }
        const g = brandMap.get(key);
        g.units += Number(item.UnitsSold || item.unitsSold || 0);
        g.orders += Number(item.OrderCount || item.orderCount || 0);
        g.revenue += Number(item.Revenue || item.revenue || 0);
      });
      groups = Array.from(brandMap.values()).map(g => ({
        ...g,
        avgPrice: g.units > 0 ? (g.revenue / g.units) : 0
      }));
    } else if (state.viewBy === 'category') {
      const catMap = new Map();
      rawItems.forEach(item => {
        const key = item.CategoryName || item.categoryName || 'Unknown Category';
        if (!catMap.has(key)) {
          catMap.set(key, { title: key, brand: '', category: key, units: 0, orders: 0, revenue: 0 });
        }
        const g = catMap.get(key);
        g.units += Number(item.UnitsSold || item.unitsSold || 0);
        g.orders += Number(item.OrderCount || item.orderCount || 0);
        g.revenue += Number(item.Revenue || item.revenue || 0);
      });
      groups = Array.from(catMap.values()).map(g => ({
        ...g,
        avgPrice: g.units > 0 ? (g.revenue / g.units) : 0
      }));
    }

    // 2. Sort by selected metric
    if (state.metric === 'units') {
      groups.sort((a, b) => (b.units - a.units) || (b.revenue - a.revenue) || a.title.localeCompare(b.title));
    } else if (state.metric === 'revenue') {
      groups.sort((a, b) => (b.revenue - a.revenue) || (b.units - a.units) || a.title.localeCompare(b.title));
    } else if (state.metric === 'orders') {
      groups.sort((a, b) => (b.orders - a.orders) || (b.revenue - a.revenue) || a.title.localeCompare(b.title));
    }

    // 3. Strictly Top 5 items
    const top5 = groups.slice(0, state.topN);

    // Check if there are valid non-zero metrics
    const hasData = top5.length > 0 && top5.some(i => {
      if (state.metric === 'units') return i.units > 0;
      if (state.metric === 'revenue') return i.revenue > 0;
      if (state.metric === 'orders') return i.orders > 0;
      return false;
    });

    if (!hasData) {
      container.innerHTML = `
        <div class="admin-empty-state">
          <div class="admin-empty-title">No Sales Data Found</div>
          <p class="admin-empty-desc">No completed transactions recorded for this selection.</p>
        </div>`;
      return;
    }

    // 4. Compute Dynamic Values for Selected Metric
    top5.forEach(i => {
      if (state.metric === 'units') i.metricVal = i.units;
      else if (state.metric === 'revenue') i.metricVal = i.revenue;
      else if (state.metric === 'orders') i.metricVal = i.orders;
    });

    const maxVal = Math.max(...top5.map(i => i.metricVal), 1);
    const { ticks, max: scaleMax } = calculateScaleTicks(maxVal);

    // 5. Build Vertical Dashed Gridlines HTML
    const gridlinesHtml = ticks.map(tick => {
      if (tick === 0) return '';
      const leftPercent = (tick / scaleMax) * 100;
      return `<div class="admin-mono-gridline" style="left: ${leftPercent}%;"></div>`;
    }).join('');

    // 6. Build Y-Axis Labels & Horizontal Rows HTML
    const labelsHtml = top5.map(item => {
      const displayName = escapeHtml(item.title);
      return `<div class="admin-mono-label" title="${displayName}">${displayName}</div>`;
    }).join('');

    const rowsHtml = top5.map((item, idx) => {
      const isTop = idx === 0;
      const barClass = isTop ? 'admin-mono-bar admin-mono-bar--top' : 'admin-mono-bar admin-mono-bar--other';
      const percentWidth = Math.min(100, Math.max(3, (item.metricVal / scaleMax) * 100));
      const valFormatted = formatDisplayVal(item.metricVal, state.metric);
      const revFormatted = '\u20B1' + item.revenue.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const avgFormatted = '\u20B1' + item.avgPrice.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

      return `
        <div class="admin-mono-row">
          <div class="admin-mono-bar-wrap">
            <div class="${barClass}" style="width: ${percentWidth}%;">
              <div class="admin-mono-tooltip">
                <span class="admin-mono-tooltip-title">${escapeHtml(item.title)}</span>
                <span class="admin-mono-tooltip-line">Units Sold: ${item.units.toLocaleString()}</span>
                <span class="admin-mono-tooltip-line">Orders: ${item.orders.toLocaleString()}</span>
                <span class="admin-mono-tooltip-line">Gross Revenue: ${revFormatted}</span>
                <span class="admin-mono-tooltip-line">Avg Price: ${avgFormatted}</span>
              </div>
            </div>
            <span class="admin-mono-val">${valFormatted}</span>
          </div>
        </div>
      `;
    }).join('');

    // 7. Build Bottom X-Axis Ticks HTML
    const ticksHtml = ticks.map(tick => {
      const leftPercent = (tick / scaleMax) * 100;
      const tickLabel = formatTickVal(tick, state.metric);
      return `<span class="admin-mono-tick" style="left: ${leftPercent}%;">${tickLabel}</span>`;
    }).join('');

    // 8. Render Complete Razor-Sharp Monochrome Graph
    container.innerHTML = `
      <div class="admin-mono-graph">
        <div class="admin-mono-graph-body">
          <div class="admin-mono-y-axis">
            ${labelsHtml}
          </div>
          <div class="admin-mono-plot-area">
            <div class="admin-mono-gridlines">
              ${gridlinesHtml}
            </div>
            ${rowsHtml}
          </div>
        </div>
        <div class="admin-mono-x-axis">
          <div class="admin-mono-x-axis-ticks">
            ${ticksHtml}
          </div>
        </div>
      </div>
    `;
  }

  function calculateScaleTicks(maxVal) {
    let roughStep = maxVal / 4;
    let magnitude = Math.pow(10, Math.floor(Math.log10(roughStep || 1)));
    let normalized = roughStep / magnitude;
    let step;
    if (normalized <= 1.5) step = 1 * magnitude;
    else if (normalized <= 3) step = 2 * magnitude;
    else if (normalized <= 7) step = 5 * magnitude;
    else step = 10 * magnitude;
    step = Math.max(1, Math.round(step));
    let tickMax = Math.ceil(maxVal / step) * step;
    if (tickMax === 0) tickMax = 4;
    const ticksArr = [];
    for (let v = 0; v <= tickMax; v += step) {
      ticksArr.push(v);
    }
    return { ticks: ticksArr, max: tickMax };
  }

  function escapeHtml(text) {
    if (!text) return '';
    return String(text)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // Initial render
  renderGraph();

  // =========================================================================
  // Modern Daily Sales Velocity Chart & View Switcher
  // =========================================================================
  const chartWrapper = document.getElementById('dailySalesChartWrapper');
  const salesCanvas = document.getElementById('dailySalesVelocityChart');
  const tableWrapper = document.getElementById('dailySalesTableWrapper');
  const paginationWrapper = document.querySelector('#dailySalesPerformanceCard .admin-pagination-container');
  const payloadEl = document.getElementById('reportsDataPayload');

  let brandDetailsCache = [];
  let brandHealthCache = [];
  let dailySalesSummaryCache = [];

  if (payloadEl) {
    try { brandDetailsCache = JSON.parse(payloadEl.getAttribute('data-brand-details') || '[]'); } catch (e) { brandDetailsCache = []; }
    try { brandHealthCache = JSON.parse(payloadEl.getAttribute('data-brand-health') || '[]'); } catch (e) { brandHealthCache = []; }
    try { dailySalesSummaryCache = JSON.parse(payloadEl.getAttribute('data-daily-sales') || '[]'); } catch (e) { dailySalesSummaryCache = []; }
  }

  let dailySalesChartInstance = null;

  if (chartWrapper && salesCanvas && window.Chart) {
    try {
      const labels = JSON.parse(chartWrapper.getAttribute('data-labels') || '[]');
      const revenues = JSON.parse(chartWrapper.getAttribute('data-revenue') || '[]');
      const orders = JSON.parse(chartWrapper.getAttribute('data-orders') || '[]');
      let dailyItems = [];
      try { dailyItems = JSON.parse(chartWrapper.getAttribute('data-daily-sales') || '[]'); } catch (e) { dailyItems = []; }

      // Note: chronSales in backend is chronological (oldest to newest), matching labels
      const ctx = salesCanvas.getContext('2d');
      const gradient = ctx.createLinearGradient(0, 0, 0, 260);
      gradient.addColorStop(0, 'rgba(24, 24, 27, 0.18)');
      gradient.addColorStop(1, 'rgba(24, 24, 27, 0.00)');

      dailySalesChartInstance = new window.Chart(ctx, {
        data: {
          labels: labels,
          datasets: [
            {
              type: 'line',
              label: 'Gross Revenue (\u20B1)',
              data: revenues,
              borderColor: '#18181B',
              backgroundColor: gradient,
              borderWidth: 2.5,
              fill: true,
              tension: 0.35,
              pointBackgroundColor: '#18181B',
              pointBorderColor: '#FFFFFF',
              pointBorderWidth: 2,
              pointRadius: 4,
              pointHoverRadius: 7,
              yAxisID: 'yRevenue',
              order: 1
            },
            {
              type: 'bar',
              label: 'Orders Count',
              data: orders,
              backgroundColor: 'rgba(113, 113, 122, 0.3)',
              hoverBackgroundColor: 'rgba(24, 24, 27, 0.8)',
              borderRadius: 4,
              barPercentage: 0.5,
              yAxisID: 'yOrders',
              order: 2
            }
          ]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          interaction: {
            mode: 'index',
            intersect: false
          },
          plugins: {
            legend: {
              display: true,
              position: 'top',
              align: 'end',
              labels: {
                boxWidth: 12,
                boxHeight: 12,
                font: { size: 11, family: 'system-ui' },
                color: '#27272A'
              }
            },
            tooltip: {
              backgroundColor: '#18181B',
              titleColor: '#FFFFFF',
              bodyColor: '#FFFFFF',
              padding: 12,
              cornerRadius: 8,
              callbacks: {
                label: function (context) {
                  if (context.dataset.yAxisID === 'yRevenue') {
                    return ' Revenue: \u20B1' + Number(context.raw).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
                  }
                  return ' Orders: ' + context.raw + ' orders';
                },
                afterBody: function (contexts) {
                  const idx = contexts[0]?.dataIndex;
                  const rev = revenues[idx] || 0;
                  const ord = orders[idx] || 0;
                  const aov = ord > 0 ? (rev / ord) : 0;
                  return [' AOV: \u20B1' + aov.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 }), '', ' \u2192 Click point to inspect itemized orders'];
                }
              }
            }
          },
          scales: {
            x: {
              grid: { display: false },
              ticks: { font: { size: 11, family: 'system-ui' }, color: '#71717A' }
            },
            yRevenue: {
              type: 'linear',
              position: 'left',
              beginAtZero: true,
              grid: { color: 'rgba(0, 0, 0, 0.05)' },
              ticks: {
                font: { size: 11, family: 'system-ui' },
                color: '#71717A',
                callback: function (val) {
                  if (val >= 1000000) return '\u20B1' + (val / 1000000).toFixed(1) + 'M';
                  if (val >= 1000) return '\u20B1' + (val / 1000).toFixed(0) + 'k';
                  return '\u20B1' + val;
                }
              }
            },
            yOrders: {
              type: 'linear',
              position: 'right',
              beginAtZero: true,
              grid: { display: false },
              ticks: {
                font: { size: 11, family: 'system-ui' },
                color: '#71717A',
                precision: 0,
                stepSize: 1
              }
            }
          },
          onClick: function (evt, elements) {
            if (!elements || elements.length === 0) return;
            const index = elements[0].index;
            // chronSales array order corresponds to labels
            let matchedItem = null;
            if (dailyItems && dailyItems.length > 0) {
              // Try finding chronological match
              const chronItems = [...dailyItems].reverse();
              matchedItem = chronItems[index] || dailyItems[index];
            }
            if (matchedItem) {
              openDailySalesDrawer(
                matchedItem.salesDate,
                matchedItem.displayDate || matchedItem.shortDate,
                matchedItem.revenue,
                matchedItem.paymentCount,
                matchedItem.averageOrderValue
              );
            }
          }
        }
      });
    } catch (e) {
      console.warn('Error initializing Daily Sales Velocity Chart:', e);
    }
  }

  // View Switcher Tabs (Guarded if present)
  const viewTabs = document.querySelectorAll('#dailySalesViewTabs button');
  if (viewTabs && viewTabs.length > 0) {
    viewTabs.forEach(btn => {
      btn.addEventListener('click', function () {
        viewTabs.forEach(b => b.classList.remove('active'));
        this.classList.add('active');
        const viewMode = this.getAttribute('data-view');

        if (viewMode === 'chart') {
          if (chartWrapper) chartWrapper.style.display = 'block';
          if (tableWrapper) tableWrapper.style.display = 'none';
          if (paginationWrapper) paginationWrapper.style.display = 'none';
          if (dailySalesChartInstance) dailySalesChartInstance.resize();
        } else if (viewMode === 'split') {
          if (chartWrapper) chartWrapper.style.display = 'block';
          if (tableWrapper) tableWrapper.style.display = 'block';
          if (paginationWrapper) paginationWrapper.style.display = 'flex';
          if (dailySalesChartInstance) dailySalesChartInstance.resize();
        } else if (viewMode === 'table') {
          if (chartWrapper) chartWrapper.style.display = 'none';
          if (tableWrapper) tableWrapper.style.display = 'block';
          if (paginationWrapper) paginationWrapper.style.display = 'flex';
        }
      });
    });
  }

  // Daily Sales Velocity Chart: Ensure chart is always visible and responsive
  if (chartWrapper) {
    chartWrapper.style.display = 'block';
  }
  window.addEventListener('resize', () => {
    if (dailySalesChartInstance) {
      dailySalesChartInstance.resize();
    }
  });

  // Table Row & Inspect Button Click -> Open Daily Sales Drawer
  document.querySelectorAll('.js-daily-sales-row, .js-daily-sales-inspect-btn').forEach(el => {
    el.addEventListener('click', function (e) {
      const date = this.getAttribute('data-date');
      const display = this.getAttribute('data-display') || date;
      if (!date) return;
      // Find summary info from cache
      const cached = dailySalesSummaryCache.find(s => s.salesDate === date);
      const rev = cached ? cached.revenue : 0;
      const orders = cached ? cached.paymentCount : 0;
      const aov = cached ? cached.averageOrderValue : 0;
      openDailySalesDrawer(date, display, rev, orders, aov);
    });
  });

  // Brand Report Row & Drilldown Button Click -> Open Brand Inventory Drawer
  document.querySelectorAll('.js-brand-report-row, .js-brand-drilldown-btn').forEach(el => {
    el.addEventListener('click', function (e) {
      // Avoid intercepting low-stock accordion toggle if clicked
      if (e.target.closest('.js-brand-inventory-toggle')) return;
      const brand = this.getAttribute('data-brand');
      if (brand) {
        openBrandInventoryDrawer(brand);
      }
    });
  });

  // =========================================================================
  // In-Page Drawers Controller
  // =========================================================================
  const dailyDrawerBackdrop = document.getElementById('dailySalesDrawerBackdrop');
  const brandDrawerBackdrop = document.getElementById('brandInventoryDrawerBackdrop');

  // Close buttons
  const btnDailyClose = document.getElementById('btnDailySalesDrawerClose');
  if (btnDailyClose && dailyDrawerBackdrop) {
    btnDailyClose.addEventListener('click', () => closeDrawer(dailyDrawerBackdrop));
    dailyDrawerBackdrop.addEventListener('click', (e) => {
      if (e.target === dailyDrawerBackdrop) closeDrawer(dailyDrawerBackdrop);
    });
  }

  const btnBrandClose = document.getElementById('btnBrandDrawerClose');
  if (btnBrandClose && brandDrawerBackdrop) {
    btnBrandClose.addEventListener('click', () => closeDrawer(brandDrawerBackdrop));
    brandDrawerBackdrop.addEventListener('click', (e) => {
      if (e.target === brandDrawerBackdrop) closeDrawer(brandDrawerBackdrop);
    });
  }

  // Escape key closes any active drawer
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (dailyDrawerBackdrop && !dailyDrawerBackdrop.hidden) closeDrawer(dailyDrawerBackdrop);
      if (brandDrawerBackdrop && !brandDrawerBackdrop.hidden) closeDrawer(brandDrawerBackdrop);
    }
  });

  function openDrawer(backdropEl) {
    if (!backdropEl) return;
    backdropEl.hidden = false;
    // Trigger transition on next animation frame
    requestAnimationFrame(() => {
      backdropEl.classList.add('is-open');
    });
    document.body.style.overflow = 'hidden';
  }

  function closeDrawer(backdropEl) {
    if (!backdropEl) return;
    backdropEl.classList.remove('is-open');
    setTimeout(() => {
      backdropEl.hidden = true;
      document.body.style.overflow = '';
    }, 280);
  }

  // --- 1. Daily Sales Orders Drawer Logic ---
  let activeDailyOrders = [];

  async function openDailySalesDrawer(dateStr, displayDate, rev, orders, aov) {
    if (!dailyDrawerBackdrop) return;
    openDrawer(dailyDrawerBackdrop);

    // Update Header and KPIs
    const titleEl = document.getElementById('dailySalesDrawerTitle');
    const revEl = document.getElementById('drawerDailyRevenue');
    const ordEl = document.getElementById('drawerDailyOrders');
    const aovEl = document.getElementById('drawerDailyAov');
    const container = document.getElementById('dailySalesOrdersContainer');
    const searchInput = document.getElementById('dailySalesSearchInput');
    if (searchInput) searchInput.value = '';

    if (titleEl) titleEl.textContent = displayDate || dateStr;
    if (revEl) revEl.innerHTML = '&#8369;' + Number(rev || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    if (ordEl) ordEl.textContent = Number(orders || 0).toLocaleString();
    if (aovEl) aovEl.innerHTML = '&#8369;' + Number(aov || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

    if (container) {
      container.innerHTML = `
        <div class="admin-drawer-loading">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="spin-icon">
            <line x1="12" y1="2" x2="12" y2="6"></line>
            <line x1="12" y1="18" x2="12" y2="22"></line>
            <line x1="4.93" y1="4.93" x2="7.76" y2="7.76"></line>
            <line x1="16.24" y1="16.24" x2="19.07" y2="19.07"></line>
            <line x1="2" y1="12" x2="6" y2="12"></line>
            <line x1="18" y1="12" x2="22" y2="12"></line>
            <line x1="4.93" y1="19.07" x2="7.76" y2="16.24"></line>
            <line x1="16.24" y1="7.76" x2="19.07" y2="4.93"></line>
          </svg>
          <span>Loading settled transactions for ${escapeHtml(displayDate || dateStr)}...</span>
        </div>`;
    }

    try {
      const res = await fetch(`/api/v1/admin/reports/daily-orders?date=${encodeURIComponent(dateStr)}`, {
        credentials: 'same-origin'
      });
      if (!res.ok) throw new Error('Failed to load orders: ' + res.status);
      const json = await res.json();
      activeDailyOrders = (json && json.data) ? json.data : (Array.isArray(json) ? json : []);
      renderDailyOrdersList(activeDailyOrders);
    } catch (err) {
      console.warn('Daily orders fetch error:', err);
      if (container) {
        container.innerHTML = `
          <div class="admin-drawer-empty">
            <p>Could not load live order details. You may view transactions in the <a href="/Admin/Orders.aspx" class="admin-row-action-btn">Orders Console &rarr;</a></p>
          </div>`;
      }
    }
  }

  function renderDailyOrdersList(ordersList) {
    const container = document.getElementById('dailySalesOrdersContainer');
    if (!container) return;

    if (!ordersList || ordersList.length === 0) {
      container.innerHTML = `
        <div class="admin-drawer-empty">
          <p>No settled customer orders recorded for this date.</p>
        </div>`;
      return;
    }

    const rowsHtml = ordersList.map(order => {
      const orderNum = escapeHtml(order.OrderNumber || order.orderNumber || ('#' + (order.OrderId || order.orderId)));
      const customer = escapeHtml(order.CustomerName || order.customerName || 'Walk-in / Guest');
      const channel = escapeHtml(order.FulfillmentType || order.fulfillmentType || order.OrderSource || order.orderSource || 'Online');
      const method = escapeHtml(order.PaymentMethod || order.paymentMethod || 'HitPay');
      const total = Number(order.TotalAmount || order.totalAmount || order.GrandTotal || 0);
      const totalFormatted = '\u20B1' + total.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const status = escapeHtml(order.OrderStatus || order.orderStatus || 'Completed');
      const orderId = order.OrderId || order.orderId;

      return `
        <tr>
          <td style="width: 28%;">
            <strong class="admin-cell-bold">${orderNum}</strong>
            <div class="admin-cell-mono-muted">${channel}</div>
          </td>
          <td style="width: 26%;">
            <div>${customer}</div>
            <div class="admin-cell-mono-muted">${method}</div>
          </td>
          <td style="width: 18%;">
            <strong class="admin-cell-price">${totalFormatted}</strong>
          </td>
          <td style="width: 14%; text-align: center;">
            <span class="admin-badge admin-badge--in-stock">${status}</span>
          </td>
          <td style="width: 14%;" class="admin-table-align-right">
            <a href="/Admin/Orders.aspx?search=${encodeURIComponent(orderNum)}" class="admin-row-action-btn" title="View order in fulfillment console">
              Inspect &rarr;
            </a>
          </td>
        </tr>`;
    }).join('');

    container.innerHTML = `
      <table class="admin-drawer-table">
        <thead>
          <tr>
            <th style="width: 28%;">Order # / Channel</th>
            <th style="width: 26%;">Customer / Payment</th>
            <th style="width: 18%;">Settled Amount</th>
            <th style="width: 14%; text-align: center;">Status</th>
            <th style="width: 14%;" class="admin-table-align-right">Action</th>
          </tr>
        </thead>
        <tbody>
          ${rowsHtml}
        </tbody>
      </table>`;
  }

  // Daily Sales Orders Search
  const dailySalesSearchInput = document.getElementById('dailySalesSearchInput');
  if (dailySalesSearchInput) {
    dailySalesSearchInput.addEventListener('input', function () {
      const q = this.value.trim().toLowerCase();
      if (!q) {
        renderDailyOrdersList(activeDailyOrders);
        return;
      }
      const filtered = activeDailyOrders.filter(o => {
        const orderNum = (o.OrderNumber || o.orderNumber || '').toLowerCase();
        const customer = (o.CustomerName || o.customerName || '').toLowerCase();
        const payment = (o.PaymentMethod || o.paymentMethod || '').toLowerCase();
        const status = (o.OrderStatus || o.orderStatus || '').toLowerCase();
        return orderNum.includes(q) || customer.includes(q) || payment.includes(q) || status.includes(q);
      });
      renderDailyOrdersList(filtered);
    });
  }

  // --- 2. Brand Inventory Health Drawer Logic ---
  let activeBrandVariants = [];
  let currentBrandFilter = 'all';

  async function openBrandInventoryDrawer(brandName) {
    if (!brandDrawerBackdrop) return;
    openDrawer(brandDrawerBackdrop);

    const titleEl = document.getElementById('brandDrawerTitle');
    const skusEl = document.getElementById('drawerBrandSkus');
    const onHandEl = document.getElementById('drawerBrandOnHand');
    const availEl = document.getElementById('drawerBrandAvailable');
    const lowStockEl = document.getElementById('drawerBrandLowStock');
    const container = document.getElementById('brandInventoryItemsContainer');
    const searchInput = document.getElementById('brandInventorySearchInput');
    if (searchInput) searchInput.value = '';

    if (titleEl) titleEl.textContent = brandName + ' Inventory Health';

    // 1. Try resolving variants from client-side preloaded cache
    let variants = brandDetailsCache.filter(item => (item.Brand || item.brand || '').toLowerCase() === brandName.toLowerCase());
    if (variants && variants.length > 0) {
      activeBrandVariants = variants;
      updateBrandDrawerKpis(activeBrandVariants);
      renderBrandVariantsList();
      return;
    }

    // 2. Fallback fetch from API
    if (container) {
      container.innerHTML = `
        <div class="admin-drawer-loading">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="spin-icon">
            <line x1="12" y1="2" x2="12" y2="6"></line><line x1="12" y1="18" x2="12" y2="22"></line>
            <line x1="4.93" y1="4.93" x2="7.76" y2="7.76"></line><line x1="16.24" y1="16.24" x2="19.07" y2="19.07"></line>
            <line x1="2" y1="12" x2="6" y2="12"></line><line x1="18" y1="12" x2="22" y2="12"></line>
            <line x1="4.93" y1="19.07" x2="7.76" y2="16.24"></line><line x1="16.24" y1="7.76" x2="19.07" y2="4.93"></line>
          </svg>
          <span>Loading inventory SKUs for ${escapeHtml(brandName)}...</span>
        </div>`;
    }

    try {
      const res = await fetch(`/api/v1/admin/reports/brand-inventory?brand=${encodeURIComponent(brandName)}`, {
        credentials: 'same-origin'
      });
      if (!res.ok) throw new Error('Failed to load brand variants: ' + res.status);
      const json = await res.json();
      activeBrandVariants = (json && json.data) ? json.data : (Array.isArray(json) ? json : []);
      updateBrandDrawerKpis(activeBrandVariants);
      renderBrandVariantsList();
    } catch (err) {
      console.warn('Brand inventory fetch error:', err);
      if (container) {
        container.innerHTML = `
          <div class="admin-drawer-empty">
            <p>Could not load brand variants. You may view inventory in the <a href="/Admin/Inventory.aspx" class="admin-row-action-btn">Inventory Console &rarr;</a></p>
          </div>`;
      }
    }
  }

  function updateBrandDrawerKpis(variants) {
    const skusEl = document.getElementById('drawerBrandSkus');
    const onHandEl = document.getElementById('drawerBrandOnHand');
    const availEl = document.getElementById('drawerBrandAvailable');
    const lowStockEl = document.getElementById('drawerBrandLowStock');

    const totalSkus = variants.length;
    const totalOnHand = variants.reduce((sum, v) => sum + Number(v.OnHandStock || v.onHandStock || 0), 0);
    const totalAvail = variants.reduce((sum, v) => sum + Number(v.AvailableStock || v.availableStock || 0), 0);
    const totalLowStock = variants.filter(v => Number(v.AvailableStock || v.availableStock || 0) <= Number(v.ReorderPoint || v.reorderPoint || 0)).length;

    if (skusEl) skusEl.textContent = totalSkus.toLocaleString();
    if (onHandEl) onHandEl.textContent = totalOnHand.toLocaleString();
    if (availEl) availEl.textContent = totalAvail.toLocaleString();
    if (lowStockEl) lowStockEl.textContent = totalLowStock.toLocaleString();
  }

  function renderBrandVariantsList() {
    const container = document.getElementById('brandInventoryItemsContainer');
    if (!container) return;

    const searchVal = (document.getElementById('brandInventorySearchInput')?.value || '').trim().toLowerCase();

    let filtered = activeBrandVariants.filter(item => {
      const avail = Number(item.AvailableStock || item.availableStock || 0);
      const reorder = Number(item.ReorderPoint || item.reorderPoint || 0);

      if (currentBrandFilter === 'alert' && avail > reorder) return false;
      if (currentBrandFilter === 'healthy' && avail <= reorder) return false;

      if (searchVal) {
        const prod = (item.ProductName || item.productName || '').toLowerCase();
        const sku = (item.SKU || item.sku || '').toLowerCase();
        const color = (item.Color || item.color || '').toLowerCase();
        const size = (item.Size || item.size || '').toLowerCase();
        const cat = (item.CategoryName || item.categoryName || '').toLowerCase();
        return prod.includes(searchVal) || sku.includes(searchVal) || color.includes(searchVal) || size.includes(searchVal) || cat.includes(searchVal);
      }
      return true;
    });

    if (filtered.length === 0) {
      container.innerHTML = `
        <div class="admin-drawer-empty">
          <p>No helmet variants match the current filter.</p>
        </div>`;
      return;
    }

    const rowsHtml = filtered.map(item => {
      const prodName = escapeHtml(item.ProductName || item.productName || 'Helmet');
      const catName = escapeHtml(item.CategoryName || item.categoryName || 'Full Face');
      const color = escapeHtml(item.Color || item.color || '');
      const size = escapeHtml(item.Size || item.size || '');
      const sku = escapeHtml(item.SKU || item.sku || '');
      let image = item.MainImageUrl || item.mainImageUrl || '/Content/images/placeholder-helmet.png';
      if (!image.startsWith('/') && !image.startsWith('http')) image = '/Content/images/placeholder-helmet.png';

      const onHand = Number(item.OnHandStock || item.onHandStock || 0);
      const avail = Number(item.AvailableStock || item.availableStock || 0);
      const reorder = Number(item.ReorderPoint || item.reorderPoint || 0);

      const isOut = avail <= 0;
      const isLow = avail > 0 && avail <= reorder;
      const statusBadge = isOut ?
        '<span class="admin-badge admin-badge--critical-alert">Out of Stock</span>' :
        isLow ?
        '<span class="admin-badge admin-badge--warning-alert">Low Stock</span>' :
        '<span class="admin-badge admin-badge--in-stock">Healthy</span>';

      const prodId = item.ProductId || item.productId;
      const varId = item.VariantId || item.variantId;

      return `
        <tr>
          <td style="width: 48%;">
            <div class="admin-drawer-product-cell">
              <img src="${escapeHtml(image)}" alt="${prodName}" class="admin-drawer-thumb" loading="lazy" />
              <div class="admin-drawer-product-info">
                <strong class="admin-cell-bold">${prodName}</strong>
                <div class="admin-cell-desc">${color} &bull; Size ${size}</div>
                <div class="admin-cell-meta">
                  <span class="admin-cell-sku-pill">${sku}</span>
                  <span class="admin-cell-cat-tag">${catName}</span>
                </div>
              </div>
            </div>
          </td>
          <td style="width: 22%;">
            <div class="admin-stock-primary">
              <strong class="${isOut ? 'admin-text-danger' : (isLow ? 'admin-text-amber' : 'admin-text-success')}">${avail}</strong> units
            </div>
            <div class="admin-cell-mono-muted">${onHand !== avail ? `On-hand: ${onHand} &bull; ` : ''}Min: ${reorder}</div>
          </td>
          <td style="width: 16%; text-align: center;">
            ${statusBadge}
          </td>
          <td style="width: 14%;" class="admin-table-align-right">
            <a href="/Admin/Inventory.aspx?productId=${prodId}&variantId=${varId}" class="admin-row-action-btn" title="Inspect variant in inventory">
              Inspect &rarr;
            </a>
          </td>
        </tr>`;
    }).join('');

    container.innerHTML = `
      <table class="admin-drawer-table">
        <thead>
          <tr>
            <th style="width: 48%;">Product &amp; Variant</th>
            <th style="width: 22%;">Available Stock</th>
            <th style="width: 16%; text-align: center;">Health Status</th>
            <th style="width: 14%;" class="admin-table-align-right">Action</th>
          </tr>
        </thead>
        <tbody>
          ${rowsHtml}
        </tbody>
      </table>`;
  }

  // Brand Drawer Search & Filter Tabs
  const brandSearchInput = document.getElementById('brandInventorySearchInput');
  if (brandSearchInput) {
    brandSearchInput.addEventListener('input', renderBrandVariantsList);
  }

  const brandFilterTabs = document.querySelectorAll('#brandInventoryFilterTabs button');
  brandFilterTabs.forEach(btn => {
    btn.addEventListener('click', function () {
      brandFilterTabs.forEach(b => b.classList.remove('active'));
      this.classList.add('active');
      currentBrandFilter = this.getAttribute('data-filter') || 'all';
      renderBrandVariantsList();
    });
  });
});
