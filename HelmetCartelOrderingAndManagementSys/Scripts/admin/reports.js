/**
 * Helmet Cartel Operations - Reports & Analytics Scripts
 * Chart.js initialization & date range management
 */
document.addEventListener('DOMContentLoaded', function () {
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
  const chartCanvas = document.getElementById('analyticsRevenueChart');
  if (!chartCanvas || !window.Chart) return;

  try {
    const labels = JSON.parse(chartCanvas.getAttribute('data-labels') || '[]');
    const revenueData = JSON.parse(chartCanvas.getAttribute('data-revenue') || '[]');
    const orderData = JSON.parse(chartCanvas.getAttribute('data-orders') || '[]');

    const ctx = chartCanvas.getContext('2d');
    const gradient = ctx.createLinearGradient(0, 0, 0, 240);
    gradient.addColorStop(0, 'rgba(24, 24, 27, 0.18)');
    gradient.addColorStop(1, 'rgba(24, 24, 27, 0.00)');

    new window.Chart(ctx, {
      type: 'line',
      data: {
        labels: labels.length ? labels : ['No Activity'],
        datasets: [
          {
            label: 'Revenue (\u20B1)',
            data: revenueData.length ? revenueData : [0],
            borderColor: '#18181B',
            backgroundColor: gradient,
            borderWidth: 2,
            fill: true,
            tension: 0.35,
            pointBackgroundColor: '#18181B',
            pointBorderColor: '#FFFFFF',
            pointBorderWidth: 2,
            pointRadius: 4,
            pointHoverRadius: 6,
            yAxisID: 'y'
          },
          {
            label: 'Orders',
            data: orderData.length ? orderData : [0],
            borderColor: '#71717A',
            borderDash: [5, 5],
            backgroundColor: 'transparent',
            borderWidth: 2,
            tension: 0.35,
            pointBackgroundColor: '#71717A',
            pointBorderColor: '#FFFFFF',
            pointBorderWidth: 2,
            pointRadius: 3,
            yAxisID: 'y1'
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
            padding: 10,
            cornerRadius: 8,
            callbacks: {
              label: function (context) {
                if (context.datasetIndex === 0) {
                  return ' Revenue: \u20B1' + Number(context.raw).toLocaleString('en-US', { minimumFractionDigits: 2 });
                } else {
                  return ' Orders: ' + Number(context.raw) + ' paid';
                }
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
          },
          y1: {
            beginAtZero: true,
            position: 'right',
            grid: { drawOnChartArea: false },
            ticks: {
              font: { size: 11, family: 'system-ui' },
              color: '#A1A1AA',
              stepSize: 1,
              precision: 0
            }
          }
        }
      }
    });
  } catch (e) {
    console.warn('Reports chart init error:', e);
  }
});
