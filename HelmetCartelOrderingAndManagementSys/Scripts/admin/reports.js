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
});
