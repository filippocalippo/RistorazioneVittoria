import React, { useEffect, useMemo, useState, useCallback } from 'https://esm.sh/react@18';
import OrdersListClean from '../components/OrdersListClean.js';
import OrderDetailsClean from '../components/OrderDetailsClean.js';

const e = React.createElement;

function mapTipo(tipo) {
  if (!tipo) return { label: 'Altro', className: '', icon: '📦' };
  if (tipo === 'delivery') return { label: 'Consegna', className: 'badge-delivery', icon: '🚚' };
  if (tipo === 'takeaway') return { label: 'Asporto', className: 'badge-takeaway', icon: '🛍️' };
  return { label: 'Altro', className: '', icon: '📦' };
}

function formatDateTime(value) {
  if (!value) return '';
  try {
    const date = new Date(value);
    return date.toLocaleString('it-IT');
  } catch (_) {
    return String(value);
  }
}

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

export default function PrinterDashboard() {
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [selectedOrderId, setSelectedOrderId] = useState(null);

  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all');
  const [typeFilter, setTypeFilter] = useState('all');

  const [detailsLoading, setDetailsLoading] = useState(false);
  const [detailsError, setDetailsError] = useState('');
  const [items, setItems] = useState([]);

  const [autoRefresh, setAutoRefresh] = useState(true);
  const [lastUpdate, setLastUpdate] = useState(null);

  const selectedOrder = useMemo(
    () => orders.find(o => String(o.id) === String(selectedOrderId)) || null,
    [orders, selectedOrderId]
  );

  const filteredOrders = useMemo(() => {
    return orders.filter(order => {
      const term = search.trim().toLowerCase();

      if (term) {
        const haystack = [
          order.numero_ordine,
          order.id,
          order.nome_cliente,
          order.telefono_cliente,
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();

        if (!haystack.includes(term)) {
          return false;
        }
      }

      if (statusFilter !== 'all') {
        const stato = (order.stato || '').toLowerCase();
        if (statusFilter === 'confirmed' && stato !== 'confirmed') return false;
        if (statusFilter === 'pending' && stato !== 'pending') return false;
      }

      if (typeFilter !== 'all') {
        const tipo = (order.tipo || order.tipo_ordine || '').toLowerCase();
        if (typeFilter !== tipo) return false;
      }

      return true;
    });
  }, [orders, search, statusFilter, typeFilter]);

  const loadOrders = useCallback(async () => {
    setLoading(true);
    setError('');
    setStatus('');

    try {
      const res = await fetch('/api/orders');
      const data = await res.json();

      if (!data.ok) {
        throw new Error(data.error || 'Errore recupero ordini');
      }

      const list = Array.isArray(data.orders) ? data.orders : [];
      setOrders(list);

      if (list.length && !selectedOrderId) {
        setSelectedOrderId(list[0].id);
      }

      setStatus('Ordini aggiornati');
      setLastUpdate(new Date());
    } catch (err) {
      console.error(err);
      setError(err.message || 'Errore sconosciuto durante il recupero degli ordini');
    } finally {
      setLoading(false);
    }
  }, [selectedOrderId]);

  async function loadOrderItems(orderId) {
    if (!orderId) return;
    setDetailsLoading(true);
    setDetailsError('');

    try {
      const res = await fetch(`/api/orders/${orderId}/items`);
      const data = await res.json();

      if (!data.ok) {
        throw new Error(data.error || 'Errore recupero prodotti ordine');
      }

      setItems(Array.isArray(data.items) ? data.items : []);
    } catch (err) {
      console.error(err);
      setDetailsError(err.message || 'Errore durante il recupero dei dettagli ordine');
    } finally {
      setDetailsLoading(false);
    }
  }

  async function handlePrint(order) {
    if (!order) return;
    setStatus('Invio stampa ordine...');
    setError('');

    try {
      const res = await fetch(`/api/orders/${order.id}/print`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ sizeFactor: 0.8 }),
      });

      const data = await res.json();
      if (!data.ok) {
        throw new Error(data.error || 'Errore stampa ordine');
      }

      setStatus('Ordine inviato alla stampante.');
      loadOrders();
    } catch (err) {
      console.error(err);
      setError(err.message || 'Errore durante la stampa');
    }
  }

  function handleSelectOrder(orderId) {
    setSelectedOrderId(orderId);
    setItems([]);
    setDetailsError('');
    loadOrderItems(orderId);
  }

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  useEffect(() => {
    if (selectedOrderId) {
      loadOrderItems(selectedOrderId);
    }
  }, [selectedOrderId]);

  // Auto-refresh every 30 seconds
  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      loadOrders();
    }, 30000);

    return () => clearInterval(interval);
  }, [autoRefresh, loadOrders]);

  // Keyboard shortcuts
  useEffect(() => {
    const handleKeyPress = (e) => {
      // R key for refresh
      if (e.key === 'r' || e.key === 'R') {
        if (!e.ctrlKey && !e.metaKey && document.activeElement.tagName !== 'INPUT') {
          e.preventDefault();
          loadOrders();
        }
      }

      // P key for print
      if (e.key === 'p' || e.key === 'P') {
        if (!e.ctrlKey && !e.metaKey && document.activeElement.tagName !== 'INPUT') {
          e.preventDefault();
          if (selectedOrder) handlePrint(selectedOrder);
        }
      }

      // Arrow keys for navigation
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        if (document.activeElement.tagName !== 'INPUT') {
          e.preventDefault();
          const currentIndex = filteredOrders.findIndex(o => String(o.id) === String(selectedOrderId));
          if (currentIndex !== -1) {
            const nextIndex = e.key === 'ArrowDown'
              ? Math.min(currentIndex + 1, filteredOrders.length - 1)
              : Math.max(currentIndex - 1, 0);
            if (filteredOrders[nextIndex]) {
              handleSelectOrder(filteredOrders[nextIndex].id);
            }
          }
        }
      }
    };

    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, [selectedOrder, filteredOrders, selectedOrderId]);

  const statusClassName = error
    ? 'status-message-error'
    : status
      ? 'status-message-success'
      : '';

  return e(React.Fragment, null,
    e('div', { className: 'app-two-columns' },
      // Orders List
      e('section', { className: 'card' },
        e('div', { className: 'card-header' },
          e('div', null,
            e('div', { className: 'card-title' },
              'Ordini',
              lastUpdate && e('span', {
                className: 'last-update',
                title: lastUpdate.toLocaleString('it-IT')
              },
                ` · ${formatTime(lastUpdate)}`
              )
            ),
            e('div', { className: 'card-subtitle' },
              loading
                ? 'Caricamento in corso...'
                : `${filteredOrders.length} di ${orders.length} ordini`
            )
          ),
          e('div', { style: { display: 'flex', gap: '8px', alignItems: 'center' } },
            e('button', {
              className: 'button button-ghost button-small',
              onClick: () => loadOrders(),
              title: 'Aggiorna ordini (R)'
            }, 'Aggiorna')
          )
        ),

        e('div', { className: 'filters-row' },
          e('input', {
            className: 'input',
            placeholder: 'Cerca per numero, cliente o telefono...',
            value: search,
            onChange: e => setSearch(e.target.value)
          }),
          e('select', {
            className: 'select',
            value: statusFilter,
            onChange: e => setStatusFilter(e.target.value)
          },
            e('option', { value: 'all' }, 'Tutti gli stati'),
            e('option', { value: 'confirmed' }, 'Confermati'),
            e('option', { value: 'pending' }, 'In attesa')
          ),
          e('select', {
            className: 'select',
            value: typeFilter,
            onChange: e => setTypeFilter(e.target.value)
          },
            e('option', { value: 'all' }, 'Tutti i tipi'),
            e('option', { value: 'delivery' }, 'Consegna'),
            e('option', { value: 'takeaway' }, 'Asporto')
          )
        ),

        e('div', { className: 'orders-list-scroll' },
          loading
            ? e('div', { className: 'empty-state' },
              e('div', { className: 'spinner' }),
              e('div', { className: 'empty-state-text' }, 'Caricamento ordini...')
            )
            : filteredOrders.length === 0
              ? e('div', { className: 'empty-state' },
                e('div', { className: 'empty-state-icon' }, '🔍'),
                e('div', { className: 'empty-state-text' }, 'Nessun ordine trovato'),
                e('div', { className: 'empty-state-hint' }, 'Prova a modificare i filtri')
              )
              : e(OrdersListClean, {
                orders: filteredOrders,
                selectedOrderId: selectedOrderId,
                onSelect: handleSelectOrder
              })
        )
      ),

      // Order Details
      e('section', { className: 'card' },
        e('div', { className: 'card-header' },
          e('div', null,
            e('div', { className: 'card-title' },
              'Dettaglio ordine'
            ),
            e('div', { className: 'card-subtitle' },
              selectedOrder
                ? `Ordine #${selectedOrder.numero_ordine || selectedOrder.id}`
                : 'Seleziona un ordine dalla lista'
            )
          ),
          selectedOrder && e('button', {
            className: 'button button-primary button-small',
            onClick: () => handlePrint(selectedOrder),
            title: 'Stampa ordine (P)'
          }, 'Stampa')
        ),

        e(OrderDetailsClean, {
          order: selectedOrder,
          items: items,
          loading: detailsLoading,
          error: detailsError,
          mapTipo: mapTipo,
          formatEuro: formatEuro,
          formatDateTime: formatDateTime,
          formatTime: formatTime
        })
      )
    ),

    // Status Bar
    e('div', { className: 'status-bar' },
      e('div', { className: statusClassName }, error || status || '\u00A0'),
      e('div', { className: 'keyboard-shortcuts' },
        e('span', { className: 'shortcut' },
          e('kbd', null, 'R'),
          ' Aggiorna'
        ),
        e('span', { className: 'shortcut' },
          e('kbd', null, 'P'),
          ' Stampa'
        ),
        e('span', { className: 'shortcut' },
          e('kbd', null, '↑↓'),
          ' Naviga'
        )
      )
    )
  );
}
