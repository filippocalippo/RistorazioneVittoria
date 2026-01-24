import React from 'https://esm.sh/react@18';

function formatTime(value) {
  if (!value) return '';
  try {
    const date = new Date(value);
    return date.toLocaleTimeString('it-IT', { hour: '2-digit', minute: '2-digit' });
  } catch (_) {
    return '';
  }
}

function formatEuro(value) {
  if (value == null) return '';
  const num = Number(value);
  if (!Number.isFinite(num)) return '';
  return num.toFixed(2) + ' €';
}

function mapTipo(tipo) {
  if (!tipo) return { label: 'Altro', className: '', icon: '' };
  if (tipo === 'delivery') return { label: 'Consegna', className: 'badge-delivery', icon: '' };
  if (tipo === 'takeaway') return { label: 'Asporto', className: 'badge-takeaway', icon: '' };
  return { label: 'Altro', className: '', icon: '' };
}

function mapStatus(stato) {
  const value = (stato || '').toLowerCase();
  if (value === 'confirmed') return { label: 'Confermato', className: 'badge-status-confirmed', icon: '' };
  if (value === 'pending') return { label: 'In attesa', className: 'badge-status-pending', icon: '' };
  return { label: stato || 'Altro', className: 'badge-status-other', icon: '' };
}

export default function OrdersListClean({ orders, selectedOrderId, onSelect }) {
  return React.createElement('div', { className: 'orders-list' },
    orders.map((order) => {
      const isActive = String(order.id) === String(selectedOrderId);
      const tipoInfo = mapTipo(order.tipo || order.tipo_ordine);
      const statusInfo = mapStatus(order.stato);

      return React.createElement('button', {
        key: order.id,
        type: 'button',
        className: `order-row${isActive ? ' active' : ''}${order.printed ? ' printed' : ''}`,
        onClick: () => onSelect(order.id),
        tabIndex: 0,
        'aria-label': `Ordine ${order.numero_ordine || order.id} da ${order.nome_cliente}`,
      },
        React.createElement('div', { className: 'order-row-main' },
          React.createElement('div', { className: 'order-row-header' },
            React.createElement('span', { className: 'order-row-number' },
              `#${order.numero_ordine || order.id}`
            ),
            React.createElement('span', { className: 'order-row-customer' },
              order.nome_cliente || 'Cliente sconosciuto'
            )
          ),
          order.telefono_cliente && React.createElement('div', { className: 'order-row-meta' },
            React.createElement('span', { className: 'order-row-phone' },
              order.telefono_cliente
            )
          ),
          React.createElement('div', { className: 'order-row-tags' },
            React.createElement('span', { className: `badge ${tipoInfo.className}` },
              React.createElement('span', { className: 'badge-icon' }, tipoInfo.icon),
              tipoInfo.label
            ),
            React.createElement('span', { className: `badge ${statusInfo.className}` },
              React.createElement('span', { className: 'badge-icon' }, statusInfo.icon),
              statusInfo.label
            ),
            order.printed && React.createElement('span', { className: 'badge badge-printed' },
              React.createElement('span', { className: 'badge-icon' }, ''),
              'Stampato'
            )
          )
        ),
        React.createElement('div', { className: 'order-row-right' },
          React.createElement('div', { className: 'order-row-amount' }, formatEuro(order.totale)),
          React.createElement('div', { className: 'order-row-time' }, formatTime(order.created_at))
        )
      );
    })
  );
}
