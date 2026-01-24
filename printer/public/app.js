import React, { useState } from 'https://esm.sh/react@18';
import ReactDOM from 'https://esm.sh/react-dom@18/client';
import PrinterDashboard from './screens/PrinterDashboard.js';
import SettingsScreen from './screens/SettingsScreen.js';

const e = React.createElement;

function App() {
  const [currentScreen, setCurrentScreen] = useState('dashboard'); // 'dashboard' | 'settings'

  return e('div', { className: 'app-shell' },
    // --- Header ---
    e('header', { className: 'app-header' },
      e('div', { className: 'app-title-block' },
        e('h1', { className: 'app-title' },
          e('span', { className: 'logo-dot' }),
          e('span', null, 'Printer Server')
        ),
        e('p', { className: 'app-subtitle' }, 'Order Management & Print Station')
      ),
      
      e('div', { className: 'app-header-actions' },
        e('div', { className: 'nav-tabs' },
          e('div', { 
            className: `nav-tab ${currentScreen === 'dashboard' ? 'active' : ''}`,
            onClick: () => setCurrentScreen('dashboard')
          }, 'Dashboard'),
          e('div', { 
            className: `nav-tab ${currentScreen === 'settings' ? 'active' : ''}`,
            onClick: () => setCurrentScreen('settings')
          }, 'Settings')
        )
      )
    ),

    // --- Main Content ---
    e('main', { className: 'app-main' },
      currentScreen === 'dashboard' 
        ? e(PrinterDashboard)
        : e(SettingsScreen)
    )
  );
}

const container = document.getElementById('root');
if (container) {
  const root = ReactDOM.createRoot(container);
  root.render(e(App));
}
