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
});
