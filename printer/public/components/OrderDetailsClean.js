import React from 'https://esm.sh/react@18';

function DetailRow({ label, value, fullWidth = false }) {
  return React.createElement('div', {
    className: `detail-row${fullWidth ? ' full-width' : ''}`
  },
    React.createElement('div', { className: 'details-label' }, label),
    React.createElement('div', { className: 'details-value' }, value || '-')
  );
}

export default function OrderDetailsClean({
  order,
  items,
  loading,
  error,
  mapTipo,
  formatEuro,
  formatDateTime,
  formatTime,
}) {
  if (!order) {
    return React.createElement('div', { className: 'empty-state' },
      React.createElement('div', { className: 'empty-state-icon' }, ''),
      React.createElement('div', { className: 'empty-state-text' },
        'Seleziona un ordine per vedere i dettagli'
      )
    );
  }

  if (loading && !items.length) {
    return React.createElement('div', { className: 'empty-state' },
      React.createElement('div', { className: 'spinner' }),
      React.createElement('div', { className: 'empty-state-text' },
        'Caricamento dettagli...'
      )
    );
  }

  const tipoInfo = mapTipo(order.tipo || order.tipo_ordine);
  const hasDeliveryInfo = order.indirizzo_consegna || order.citta_consegna;

  return React.createElement('div', { className: 'details-layout' },
    error && React.createElement('div', { className: 'alert alert-error' },
      React.createElement('span', { className: 'alert-icon' }, ''),
      error
    ),

    // Order Summary Card
    React.createElement('section', { className: 'details-card details-card-highlight' },
      React.createElement('div', { className: 'details-card-header' },
        React.createElement('h3', { className: 'details-section-title' },
          React.createElement('span', { className: 'section-icon' }, ''),
          'Riepilogo Ordine'
        ),
        React.createElement('div', { className: 'order-badges' },
          React.createElement('span', { className: `badge ${tipoInfo.className}` },
            React.createElement('span', { className: 'badge-icon' }, tipoInfo.icon),
            tipoInfo.label
          ),
          order.printed && React.createElement('span', { className: 'badge badge-printed' },
            React.createElement('span', { className: 'badge-icon' }, ''),
            'Stampato'
          )
        )
      ),
      React.createElement('div', { className: 'details-grid' },
        React.createElement(DetailRow, {
          label: 'Numero ordine',
          value: `#${order.numero_ordine || order.id}`
        }),
        React.createElement(DetailRow, {
          label: 'Data e ora',
          value: formatDateTime(order.created_at)
        }),
        React.createElement(DetailRow, {
          label: 'Stato',
          value: order.stato
        }),
        React.createElement(DetailRow, {
          label: 'Totale',
          value: React.createElement('strong', { className: 'price-highlight' },
            formatEuro(order.totale)
          )
        })
      )
    ),

    // Customer Info
    React.createElement('section', { className: 'details-card' },
      React.createElement('h3', { className: 'details-section-title' },
        React.createElement('span', { className: 'section-icon' }, ''),
        'Cliente'
      ),
      React.createElement('div', { className: 'details-grid' },
        React.createElement(DetailRow, { label: 'Nome', value: order.nome_cliente }),
        React.createElement(DetailRow, { label: 'Telefono', value: order.telefono_cliente }),
        hasDeliveryInfo && [
          React.createElement(DetailRow, {
            key: 'addr',
            label: 'Indirizzo',
            value: order.indirizzo_consegna,
            fullWidth: true
          }),
          React.createElement(DetailRow, {
            key: 'city',
            label: 'Città',
            value: order.citta_consegna
          })
        ]
      )
    ),

    // Products
    React.createElement('section', { className: 'details-card' },
      React.createElement('h3', { className: 'details-section-title' },
        React.createElement('span', { className: 'section-icon' }, ''),
        `Prodotti (${items.length})`
      ),
      items.length === 0
        ? React.createElement('div', { className: 'empty-state-small' },
          loading ? 'Caricamento prodotti...' : 'Nessun prodotto trovato'
        )
        : React.createElement('div', { className: 'details-items-list' },
          items.map(item =>
            React.createElement('div', { key: item.id, className: 'details-item-row' },
              React.createElement('div', { className: 'details-item-main' },
                React.createElement('div', { className: 'details-item-left' },
                  React.createElement('div', { className: 'details-item-qty' },
                    `${item.quantita || 1}×`
                  ),
                  React.createElement('div', null,
                    React.createElement('div', { className: 'details-item-name' },
                      item.nome_prodotto || 'Prodotto'
                    ),
                    item.note && React.createElement('div', { className: 'details-item-note' },
                      React.createElement('span', { className: 'note-icon' }, ''),
                      item.note
                    )
                  )
                ),
                item.prezzo_unitario != null && React.createElement('div', { className: 'details-item-price' },
                  formatEuro(item.prezzo_unitario)
                )
              )
            )
          )
        )
    ),

    // Order Notes
    order.note && React.createElement('section', { className: 'details-card' },
      React.createElement('h3', { className: 'details-section-title' },
        React.createElement('span', { className: 'section-icon' }, ''),
        'Note Ordine'
      ),
      React.createElement('div', { className: 'order-note-content' }, order.note)
    )
  );
}
