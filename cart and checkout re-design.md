<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gourmet Checkout</title>
    
    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    
    <!-- Google Fonts -->
    <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    
    <!-- Phosphor Icons -->
    <script src="https://unpkg.com/@phosphor-icons/web"></script>

    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: {
                        sans: ['Outfit', 'sans-serif'],
                    },
                    colors: {
                        brand: {
                            DEFAULT: '#ACC7BE', 
                            dark: '#8FA8A0',
                            light: '#E6EFEC',
                            ultralight: '#F5F9F7'
                        }
                    },
                    boxShadow: {
                        'soft': '0 10px 40px -10px rgba(0,0,0,0.08)',
                        'card': '0 4px 20px -5px rgba(0,0,0,0.05)',
                        'up': '0 -10px 40px -10px rgba(0,0,0,0.1)',
                    },
                    borderRadius: {
                        '3xl': '1.5rem',
                    }
                }
            }
        }
    </script>

    <style>
        .no-scrollbar::-webkit-scrollbar { display: none; }
        .no-scrollbar { -ms-overflow-style: none; scrollbar-width: none; }
        
        .fade-in { animation: fadeIn 0.4s cubic-bezier(0.16, 1, 0.3, 1); }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .glass-panel {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(12px);
        }

        /* Bottom Sheet Transitions */
        .bottom-sheet {
            transition: transform 0.4s cubic-bezier(0.16, 1, 0.3, 1);
            transform: translateY(110%);
        }
        .bottom-sheet.active {
            transform: translateY(0);
        }
        
        .overlay {
            transition: opacity 0.3s ease;
            opacity: 0;
            pointer-events: none;
        }
        .overlay.active {
            opacity: 1;
            pointer-events: auto;
        }

        /* Card Selection Animation */
        .payment-card {
            transition: all 0.2s ease;
            border: 2px solid transparent;
        }
        .payment-card.selected {
            border-color: #ACC7BE;
            background-color: #F5F9F7;
            transform: translateY(-2px);
            box-shadow: 0 10px 30px -10px rgba(172, 199, 190, 0.4);
        }
    </style>
</head>
<body class="bg-gray-100 text-gray-800 antialiased h-screen flex justify-center overflow-hidden">

    <!-- Mobile Container -->
    <div class="w-full max-w-md h-full bg-white relative shadow-2xl overflow-hidden flex flex-col md:rounded-[2rem] md:h-[95vh] md:my-auto md:border-[8px] md:border-white">
        
        <!-- Header -->
        <header class="px-6 pt-12 pb-4 flex items-center justify-between bg-white z-20 sticky top-0">
            <button onclick="handleBack()" class="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-50 transition-colors text-gray-600">
                <i id="header-icon" class="ph ph-x text-xl"></i>
            </button>
            <h1 id="page-title" class="text-lg font-bold text-gray-900 tracking-tight">Cart</h1>
            <button class="w-10 h-10 flex items-center justify-center rounded-full hover:bg-gray-50 transition-colors text-gray-600">
                <i class="ph ph-dots-three-vertical text-xl font-bold"></i>
            </button>
        </header>

        <!-- Main Content Area -->
        <main id="app-content" class="flex-1 overflow-y-auto no-scrollbar pb-32 relative">
            <!-- Content injected via JS -->
        </main>

        <!-- Bottom Action Bar (Sticky) -->
        <div id="action-bar" class="absolute bottom-0 left-0 right-0 p-6 bg-white border-t border-gray-50 z-30 glass-panel">
            <!-- Total Row (Only visible on Cart) -->
            <div id="cart-total-preview" class="flex justify-between items-end mb-4 fade-in">
                <div>
                    <p class="text-[10px] text-gray-400 font-bold uppercase tracking-widest mb-1">Total Amount</p>
                    <p class="text-2xl font-bold text-gray-900" id="action-total-price">$33.99</p>
                </div>
            </div>

            <button onclick="handleMainAction()" id="main-action-btn" class="w-full bg-brand hover:bg-brand-dark active:scale-[0.98] transition-all duration-200 text-gray-900 font-bold py-4 rounded-2xl flex items-center justify-between px-6 shadow-soft group">
                <span id="action-btn-text">Go to Checkout</span>
                <div class="bg-white/20 px-3 py-1 rounded-lg text-sm group-hover:bg-white/30 transition">
                    <i id="action-btn-icon" class="ph-bold ph-arrow-right"></i>
                </div>
            </button>
        </div>

        <!-- Overlay for Bottom Sheet -->
        <div id="overlay" onclick="closeBottomSheet()" class="overlay absolute inset-0 bg-black/40 z-40 backdrop-blur-sm"></div>

        <!-- Order Type Bottom Sheet -->
        <div id="bottom-sheet" class="bottom-sheet absolute bottom-0 left-0 right-0 bg-white rounded-t-[2rem] z-50 shadow-up p-6 pb-10">
            <div class="w-12 h-1 bg-gray-200 rounded-full mx-auto mb-8"></div>
            <h2 class="text-xl font-bold text-gray-900 mb-6 px-1">How would you like it?</h2>
            
            <div class="grid grid-cols-2 gap-4 mb-8">
                <!-- Delivery Option -->
                <div onclick="selectOrderType('delivery')" id="opt-delivery" class="relative overflow-hidden p-5 rounded-3xl border-2 cursor-pointer transition-all duration-200 bg-brand-light border-brand">
                    <div class="absolute top-4 right-4 w-6 h-6 rounded-full bg-brand flex items-center justify-center">
                        <i class="ph-bold ph-check text-white text-xs"></i>
                    </div>
                    <div class="w-12 h-12 rounded-full bg-white mb-4 flex items-center justify-center text-brand-dark shadow-sm">
                        <i class="ph-fill ph-moped text-2xl"></i>
                    </div>
                    <h3 class="font-bold text-gray-900">Delivery</h3>
                    <p class="text-xs text-gray-500 mt-1 font-medium">~35 min</p>
                </div>

                <!-- Takeaway Option -->
                <div onclick="selectOrderType('takeaway')" id="opt-takeaway" class="relative overflow-hidden p-5 rounded-3xl border-2 border-gray-100 cursor-pointer transition-all duration-200 hover:bg-gray-50">
                    <div id="check-takeaway" class="hidden absolute top-4 right-4 w-6 h-6 rounded-full bg-brand items-center justify-center">
                        <i class="ph-bold ph-check text-white text-xs"></i>
                    </div>
                    <div class="w-12 h-12 rounded-full bg-gray-100 mb-4 flex items-center justify-center text-gray-500">
                        <i class="ph-fill ph-bag text-2xl"></i>
                    </div>
                    <h3 class="font-bold text-gray-900">Takeaway</h3>
                    <p class="text-xs text-gray-500 mt-1 font-medium">~15 min</p>
                </div>
            </div>

            <button onclick="confirmOrderType()" class="w-full bg-gray-900 text-white font-bold py-4 rounded-2xl active:scale-[0.98] transition-transform flex items-center justify-center gap-2">
                Continue
                <i class="ph-bold ph-arrow-right"></i>
            </button>
        </div>

    </div>

    <!-- Templates -->
    <template id="tpl-cart-item">
        <div class="flex gap-4 p-4 mb-4 bg-white border border-gray-50 rounded-3xl shadow-card">
            <div class="w-24 h-24 rounded-2xl bg-gray-100 overflow-hidden flex-shrink-0 relative">
                <img src="" alt="" class="w-full h-full object-cover item-img">
            </div>
            <div class="flex-1 flex flex-col justify-between py-1">
                <div>
                    <h3 class="font-bold text-gray-900 item-title leading-tight text-lg"></h3>
                    <p class="text-xs text-gray-400 mt-1 item-subtitle font-medium"></p>
                </div>
                <div class="flex items-center justify-between mt-2">
                    <span class="font-bold text-lg item-price text-brand-dark"></span>
                    
                    <div class="flex items-center bg-gray-50 rounded-xl p-1 border border-gray-100">
                        <button class="w-7 h-7 flex items-center justify-center rounded-lg bg-white shadow-sm text-gray-600 hover:text-red-500 transition btn-dec">
                            <i class="ph-bold ph-minus text-xs"></i>
                        </button>
                        <span class="w-8 text-center font-semibold text-sm item-qty">1</span>
                        <button class="w-7 h-7 flex items-center justify-center rounded-lg bg-brand text-gray-900 shadow-sm hover:brightness-95 transition btn-inc">
                            <i class="ph-bold ph-plus text-xs"></i>
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </template>

    <script>
        // State
        const state = {
            currentView: 'cart', // 'cart', 'delivery', 'checkout'
            orderType: 'delivery', // 'delivery' or 'takeaway'
            cart: [
                {
                    id: 1,
                    title: "Chicken Burger",
                    subtitle: "With Cheese & Salad",
                    price: 6.57,
                    qty: 1,
                    image: "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=300&q=80"
                },
                {
                    id: 2,
                    title: "Seafood Pizza",
                    subtitle: "Deep Dish Marinara",
                    price: 7.99,
                    qty: 1,
                    image: "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?auto=format&fit=crop&w=300&q=80"
                },
                {
                    id: 3,
                    title: "Fresh Salad",
                    subtitle: "Garden Mix",
                    price: 12.57,
                    qty: 1,
                    image: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=300&q=80"
                }
            ],
            delivery: {
                selectedDateIndex: 2,
                selectedTimeSlot: '09:00 - 10:00'
            },
            paymentMethod: 'visa',
            fees: {
                delivery: 15.00,
                discount: 0.00
            }
        };

        // DOM Elements
        const mainContent = document.getElementById('app-content');
        const pageTitle = document.getElementById('page-title');
        const headerIcon = document.getElementById('header-icon');
        const actionBtnText = document.getElementById('action-btn-text');
        const actionBtnIcon = document.getElementById('action-btn-icon');
        const actionTotalPrice = document.getElementById('action-total-price');
        const cartTotalPreview = document.getElementById('cart-total-preview');
        const bottomSheet = document.getElementById('bottom-sheet');
        const overlay = document.getElementById('overlay');
        const actionBar = document.getElementById('action-bar');

        // Utils
        const formatMoney = (amount) => `$${amount.toFixed(2)}`;
        const getDates = () => {
            const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
            const dates = [];
            for(let i=0; i<7; i++) {
                const d = new Date();
                d.setDate(d.getDate() + i);
                dates.push({
                    day: days[d.getDay()],
                    date: d.getDate(),
                    full: d
                });
            }
            return dates;
        };

        const timeSlots = [
            { time: "07:00 - 08:00", cost: 0, status: "Free" },
            { time: "08:00 - 09:00", cost: 0, status: "Free" },
            { time: "09:00 - 10:00", cost: 2.01, status: "$2.01" },
            { time: "10:00 - 11:00", cost: 1.5, status: "$1.50" },
            { time: "11:00 - 12:00", cost: 1.5, status: "$1.50" },
            { time: "12:00 - 13:00", cost: 0, status: "Free" },
        ];

        // --- Render Functions ---

        function renderCart() {
            state.currentView = 'cart';
            pageTitle.innerText = "My Cart";
            headerIcon.className = "ph ph-x text-xl";
            actionBtnText.innerText = "Go to Checkout";
            actionBtnIcon.className = "ph-bold ph-arrow-right";
            cartTotalPreview.style.display = 'flex';
            actionBar.style.display = 'block';
            
            const subtotal = state.cart.reduce((acc, item) => acc + (item.price * item.qty), 0);
            const total = subtotal + state.fees.delivery - state.fees.discount;
            actionTotalPrice.innerText = formatMoney(total);

            let html = `<div class="px-6 py-2 fade-in">`;
            
            // Items List
            html += `<div id="cart-items-container"></div>`;

            // Add Items
            html += `
                <button class="mt-4 w-full py-4 border-2 border-dashed border-gray-200 rounded-3xl text-brand-dark font-medium flex items-center justify-center gap-2 hover:bg-gray-50 hover:border-brand-dark transition-colors">
                    <i class="ph-bold ph-plus-circle text-xl"></i>
                    Add more items
                </button>
            `;

            // Promo Code
            html += `
                <div class="mt-8 mb-6">
                    <div class="flex items-center justify-between p-4 bg-gray-50 rounded-2xl cursor-pointer hover:bg-gray-100 transition border border-transparent hover:border-gray-200">
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-full bg-brand/20 flex items-center justify-center text-brand-dark">
                                <i class="ph-fill ph-ticket text-xl"></i>
                            </div>
                            <span class="font-medium text-gray-700">Add Promo Code</span>
                        </div>
                        <i class="ph ph-caret-right text-gray-400"></i>
                    </div>
                </div>
            `;

            // Breakdown
            html += `
                <div class="space-y-3 border-t border-gray-100 pt-6 mb-10">
                    <div class="flex justify-between text-gray-500 text-sm">
                        <span>Subtotal</span>
                        <span class="font-medium text-gray-900">${formatMoney(subtotal)}</span>
                    </div>
                    <div class="flex justify-between text-gray-500 text-sm">
                        <span>Discount</span>
                        <span class="font-medium text-gray-900">${formatMoney(state.fees.discount)}</span>
                    </div>
                     <div class="flex justify-between text-gray-500 text-sm">
                        <span>Delivery Fee</span>
                        <span class="font-medium text-gray-900">${formatMoney(state.fees.delivery)}</span>
                    </div>
                </div>
            `;

            html += `</div>`;
            mainContent.innerHTML = html;

            // Render items
            const container = document.getElementById('cart-items-container');
            const template = document.getElementById('tpl-cart-item');

            state.cart.forEach((item, index) => {
                const clone = template.content.cloneNode(true);
                clone.querySelector('.item-title').innerText = item.title;
                clone.querySelector('.item-subtitle').innerText = item.subtitle;
                clone.querySelector('.item-price').innerText = formatMoney(item.price);
                clone.querySelector('.item-qty').innerText = item.qty;
                clone.querySelector('.item-img').src = item.image;
                clone.querySelector('.btn-inc').onclick = () => updateQty(index, 1);
                clone.querySelector('.btn-dec').onclick = () => updateQty(index, -1);
                container.appendChild(clone);
            });
        }

        function renderDelivery() {
            state.currentView = 'delivery';
            pageTitle.innerText = state.orderType === 'delivery' ? "Delivery Details" : "Pickup Details";
            headerIcon.className = "ph ph-caret-left text-xl"; 
            actionBtnText.innerText = "Proceed to Payment";
            actionBtnIcon.className = "ph-bold ph-credit-card";
            cartTotalPreview.style.display = 'none';
            actionBar.style.display = 'block';

            const dates = getDates();

            let html = `<div class="pb-6 fade-in">`;
            
            // Location Header (Only for Delivery)
            if(state.orderType === 'delivery') {
                html += `
                    <div class="px-6 mb-8 mt-2">
                        <div class="flex items-start gap-4 p-5 bg-brand-light rounded-3xl border border-brand/20 shadow-sm">
                            <div class="w-12 h-12 rounded-full bg-brand flex items-center justify-center text-gray-800 flex-shrink-0 shadow-sm">
                                <i class="ph-fill ph-map-pin text-xl"></i>
                            </div>
                            <div class="flex-1 pt-1">
                                <p class="text-[10px] text-gray-500 font-bold uppercase tracking-widest mb-1">Delivery Address</p>
                                <div class="flex items-center justify-between">
                                    <div>
                                        <h2 class="font-bold text-gray-900 text-lg leading-tight">Banasree, B-Block</h2>
                                        <p class="text-sm text-gray-500 mt-1">Road 4, House 22</p>
                                    </div>
                                    <div class="w-8 h-8 rounded-full bg-white flex items-center justify-center cursor-pointer hover:bg-gray-50 transition">
                                        <i class="ph-bold ph-pencil-simple text-brand-dark"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            } else {
                 html += `
                    <div class="px-6 mb-8 mt-2">
                         <div class="flex items-start gap-4 p-5 bg-gray-50 rounded-3xl border border-gray-100">
                            <div class="w-12 h-12 rounded-full bg-white border border-gray-200 flex items-center justify-center text-gray-800 flex-shrink-0 shadow-sm">
                                <i class="ph-fill ph-storefront text-xl"></i>
                            </div>
                            <div class="flex-1 pt-1">
                                <p class="text-[10px] text-gray-500 font-bold uppercase tracking-widest mb-1">Pickup Location</p>
                                <h2 class="font-bold text-gray-900 text-lg leading-tight">Gourmet Central</h2>
                                <p class="text-sm text-gray-500 mt-1">123 Main Street, NY</p>
                            </div>
                        </div>
                    </div>
                `;
            }

            // Date Scroll
            html += `
                <div class="mb-8">
                    <h3 class="px-6 text-lg font-bold text-gray-900 mb-4">${state.orderType === 'delivery' ? 'Delivery Date' : 'Pickup Date'}</h3>
                    <div class="flex overflow-x-auto no-scrollbar gap-3 px-6 pb-4">
                        ${dates.map((d, i) => `
                            <div onclick="selectDate(${i})" 
                                 class="flex-shrink-0 w-[4.5rem] h-20 rounded-2xl flex flex-col items-center justify-center cursor-pointer transition-all duration-300 border-2 ${
                                i === state.delivery.selectedDateIndex 
                                ? 'bg-brand text-gray-900 border-brand shadow-lg shadow-brand/30 scale-105' 
                                : 'bg-white text-gray-400 border-gray-100 hover:border-brand/30'
                            }">
                                <span class="text-xs font-bold mb-1 uppercase tracking-wide opacity-80">${d.day}</span>
                                <span class="text-xl font-bold">${d.date}</span>
                            </div>
                        `).join('')}
                    </div>
                </div>
            `;

            // Time Slots
            html += `
                <div class="px-6">
                    <h3 class="text-lg font-bold text-gray-900 mb-4">Choose Time</h3>
                    <div class="space-y-3">
                        ${timeSlots.map(slot => `
                            <div onclick="selectTime('${slot.time}')" 
                                 class="flex items-center justify-between p-4 rounded-2xl border cursor-pointer transition-all duration-200 group ${
                                state.delivery.selectedTimeSlot === slot.time
                                ? 'border-brand bg-brand-light/40 shadow-sm'
                                : 'border-gray-100 hover:border-gray-200 hover:bg-gray-50'
                            }">
                                <span class="font-semibold text-gray-700">${slot.time}</span>
                                <div class="flex items-center gap-3">
                                    <span class="text-sm ${slot.cost > 0 ? 'text-gray-900 font-bold' : 'text-brand-dark font-bold uppercase tracking-wide text-xs'}">${slot.status}</span>
                                    <div class="w-5 h-5 rounded-full border-2 flex items-center justify-center ${
                                        state.delivery.selectedTimeSlot === slot.time 
                                        ? 'border-brand' 
                                        : 'border-gray-300'
                                    }">
                                        ${state.delivery.selectedTimeSlot === slot.time ? '<div class="w-2.5 h-2.5 rounded-full bg-brand"></div>' : ''}
                                    </div>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                </div>
            `;

            html += `</div>`;
            mainContent.innerHTML = html;
        }

        function renderCheckout() {
            state.currentView = 'checkout';
            pageTitle.innerText = "Checkout";
            headerIcon.className = "ph ph-caret-left text-xl"; 
            cartTotalPreview.style.display = 'none';
            actionBar.style.display = 'none'; // Custom button inside checkout content

            const subtotal = state.cart.reduce((acc, item) => acc + (item.price * item.qty), 0);
            const fee = state.orderType === 'delivery' ? state.fees.delivery : 0;
            const total = subtotal + fee - state.fees.discount;
            const selectedDate = getDates()[state.delivery.selectedDateIndex];

            let html = `<div class="px-6 pb-8 fade-in flex flex-col h-full">`;
            
            // 1. Delivery/Pickup Address Card (Consistent with Delivery Screen)
             html += `
                <div class="mb-6 mt-2">
                    <div class="flex items-center gap-4 p-5 bg-white rounded-3xl border border-gray-100 shadow-card">
                        <div class="w-12 h-12 rounded-full bg-brand-light flex items-center justify-center text-brand-dark flex-shrink-0">
                            <i class="ph-fill ${state.orderType === 'delivery' ? 'ph-map-pin' : 'ph-storefront'} text-xl"></i>
                        </div>
                        <div class="flex-1">
                            <p class="text-[10px] text-gray-400 font-bold uppercase tracking-widest mb-1">${state.orderType === 'delivery' ? 'Delivery To' : 'Pick up at'}</p>
                            <h2 class="font-bold text-gray-900 text-base leading-tight">
                                ${state.orderType === 'delivery' ? 'Banasree, B-Block' : 'Gourmet Central'}
                            </h2>
                             <p class="text-xs text-gray-500 mt-0.5">
                                ${state.orderType === 'delivery' ? 'Road 4, House 22' : '123 Main Street, NY'}
                             </p>
                        </div>
                        <div class="w-8 h-8 rounded-full bg-gray-50 flex items-center justify-center text-gray-400">
                            <i class="ph-bold ph-check text-green-500"></i>
                        </div>
                    </div>
                </div>
            `;

            // 2. Schedule Summary Card
            html += `
                <div class="mb-8">
                     <h3 class="text-lg font-bold text-gray-900 mb-4 px-1">Schedule</h3>
                     <div class="flex items-center gap-4 p-4 rounded-3xl border border-gray-100 bg-gray-50/50">
                        <div class="w-12 h-12 rounded-2xl bg-white border border-gray-100 flex flex-col items-center justify-center text-brand-dark shadow-sm">
                            <span class="text-[10px] font-bold uppercase">${selectedDate.day}</span>
                            <span class="text-lg font-bold leading-none text-gray-900">${selectedDate.date}</span>
                        </div>
                        <div class="flex-1">
                            <p class="font-semibold text-gray-900">${state.delivery.selectedTimeSlot}</p>
                            <p class="text-xs text-gray-500">Estimated arrival</p>
                        </div>
                        <button onclick="handleBack()" class="text-xs font-bold text-brand-dark px-3 py-1.5 bg-brand-light rounded-lg hover:bg-brand/20 transition">CHANGE</button>
                     </div>
                </div>
            `;

            // 3. Payment Method (Cards)
            html += `
                <div class="mb-8">
                    <div class="flex items-center justify-between mb-4 px-1">
                        <h3 class="text-lg font-bold text-gray-900">Payment</h3>
                        <button class="text-brand-dark text-sm font-bold flex items-center gap-1 hover:opacity-80">
                            <i class="ph-bold ph-plus"></i> Add New
                        </button>
                    </div>
                    
                    <div class="flex gap-4 overflow-x-auto no-scrollbar pb-4 -mx-6 px-6">
                        <!-- Visa Card (Selected) -->
                        <div onclick="selectPayment('visa')" class="payment-card ${state.paymentMethod === 'visa' ? 'selected' : ''} flex-shrink-0 w-64 h-36 bg-gray-900 rounded-3xl p-6 text-white relative overflow-hidden cursor-pointer group">
                             <div class="absolute top-0 right-0 w-32 h-32 bg-white/5 rounded-full -mr-10 -mt-10 blur-xl"></div>
                             <div class="flex justify-between items-start mb-6">
                                <i class="ph-fill ph-contactless-payment text-2xl opacity-80"></i>
                                <span class="font-bold italic text-lg tracking-wider">VISA</span>
                             </div>
                             <div class="mt-auto">
                                <p class="text-gray-400 text-xs mb-1 font-medium tracking-wider">CARD NUMBER</p>
                                <div class="flex items-center gap-2">
                                    <div class="flex gap-1"><div class="w-1.5 h-1.5 rounded-full bg-white"></div><div class="w-1.5 h-1.5 rounded-full bg-white"></div><div class="w-1.5 h-1.5 rounded-full bg-white"></div><div class="w-1.5 h-1.5 rounded-full bg-white"></div></div>
                                    <span class="font-mono text-lg ml-1">4242</span>
                                </div>
                             </div>
                             <!-- Selected Check -->
                             ${state.paymentMethod === 'visa' ? '<div class="absolute bottom-4 right-4 w-6 h-6 bg-brand rounded-full flex items-center justify-center text-gray-900 shadow-lg"><i class="ph-bold ph-check text-xs"></i></div>' : ''}
                        </div>

                        <!-- Mastercard -->
                        <div onclick="selectPayment('mastercard')" class="payment-card ${state.paymentMethod === 'mastercard' ? 'selected' : ''} flex-shrink-0 w-64 h-36 bg-gray-100 border border-gray-200 rounded-3xl p-6 text-gray-800 relative overflow-hidden cursor-pointer">
                             <div class="flex justify-between items-start mb-6">
                                <i class="ph-fill ph-contactless-payment text-2xl text-gray-400"></i>
                                <div class="flex -space-x-2 opacity-80">
                                    <div class="w-6 h-6 rounded-full bg-red-500/80"></div>
                                    <div class="w-6 h-6 rounded-full bg-yellow-500/80"></div>
                                </div>
                             </div>
                             <div class="mt-auto">
                                <p class="text-gray-400 text-xs mb-1 font-medium tracking-wider">CARD NUMBER</p>
                                <div class="flex items-center gap-2">
                                    <div class="flex gap-1"><div class="w-1.5 h-1.5 rounded-full bg-gray-400"></div><div class="w-1.5 h-1.5 rounded-full bg-gray-400"></div><div class="w-1.5 h-1.5 rounded-full bg-gray-400"></div><div class="w-1.5 h-1.5 rounded-full bg-gray-400"></div></div>
                                    <span class="font-mono text-lg ml-1">8888</span>
                                </div>
                             </div>
                             ${state.paymentMethod === 'mastercard' ? '<div class="absolute bottom-4 right-4 w-6 h-6 bg-brand rounded-full flex items-center justify-center text-gray-900 shadow-lg"><i class="ph-bold ph-check text-xs"></i></div>' : ''}
                        </div>
                        
                         <!-- Apple Pay -->
                         <div onclick="selectPayment('apple')" class="payment-card ${state.paymentMethod === 'apple' ? 'selected' : ''} flex-shrink-0 w-64 h-36 bg-black text-white rounded-3xl p-6 relative overflow-hidden cursor-pointer flex items-center justify-center">
                             <div class="flex items-center gap-2">
                                 <i class="ph-fill ph-apple-logo text-3xl"></i>
                                 <span class="font-bold text-xl">Pay</span>
                             </div>
                             ${state.paymentMethod === 'apple' ? '<div class="absolute bottom-4 right-4 w-6 h-6 bg-brand rounded-full flex items-center justify-center text-gray-900 shadow-lg"><i class="ph-bold ph-check text-xs"></i></div>' : ''}
                        </div>
                    </div>
                </div>
            `;

            // 4. Order Summary (Receipt Style)
            html += `
                <div class="mt-auto bg-brand-ultralight rounded-3xl p-6 pb-24 border border-brand/10 relative">
                    <h3 class="text-sm font-bold text-gray-900 mb-4 tracking-wide uppercase opacity-60">Order Summary</h3>
                    
                    <div class="space-y-3 mb-6">
                        ${state.cart.map(item => `
                            <div class="flex justify-between items-center text-sm">
                                <span class="text-gray-600 font-medium"><span class="font-bold text-gray-900 mr-2">${item.qty}x</span> ${item.title}</span>
                                <span class="font-semibold text-gray-900">${formatMoney(item.price * item.qty)}</span>
                            </div>
                        `).join('')}
                    </div>
                    
                    <!-- Dashed Divider -->
                    <div class="border-b-2 border-dashed border-gray-300 my-4 -mx-2"></div>
                    
                    <div class="space-y-2">
                        <div class="flex justify-between text-sm text-gray-500">
                            <span>Subtotal</span>
                            <span>${formatMoney(subtotal)}</span>
                        </div>
                        <div class="flex justify-between text-sm text-gray-500">
                            <span>${state.orderType === 'delivery' ? 'Delivery Fee' : 'Service Fee'}</span>
                            <span>${formatMoney(fee)}</span>
                        </div>
                         <div class="flex justify-between text-sm text-gray-500">
                            <span>Tax (5%)</span>
                            <span>${formatMoney(total * 0.05)}</span>
                        </div>
                    </div>

                    <div class="flex justify-between items-center mt-6 pt-4 border-t border-brand/20">
                        <span class="text-gray-500 font-medium">Grand Total</span>
                        <span class="text-2xl font-bold text-gray-900">${formatMoney(total * 1.05)}</span>
                    </div>

                    <!-- Floating Pay Button -->
                    <div class="absolute -bottom-6 left-0 right-0 p-6">
                        <button onclick="alert('Processing Payment...')" class="w-full bg-brand hover:bg-brand-dark text-gray-900 font-bold py-4 rounded-2xl shadow-xl shadow-brand/20 active:scale-[0.98] transition-all flex items-center justify-between px-6 group">
                            <span>Pay Now</span>
                            <div class="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center group-hover:bg-white/30 transition">
                                <i class="ph-bold ph-arrow-right"></i>
                            </div>
                        </button>
                    </div>
                </div>
            `;

            html += `</div>`;
            mainContent.innerHTML = html;
        }


        // --- Interaction Logic ---

        function handleMainAction() {
            if (state.currentView === 'cart') {
                openBottomSheet();
            } else if (state.currentView === 'delivery') {
                renderCheckout();
            }
        }

        function handleBack() {
            if (state.currentView === 'delivery') {
                renderCart();
            } else if (state.currentView === 'checkout') {
                renderDelivery();
            } else {
                console.log('Close app');
            }
        }

        // Bottom Sheet Logic
        function openBottomSheet() {
            bottomSheet.classList.add('active');
            overlay.classList.add('active');
        }

        function closeBottomSheet() {
            bottomSheet.classList.remove('active');
            overlay.classList.remove('active');
        }

        function selectOrderType(type) {
            state.orderType = type;
            
            const delEl = document.getElementById('opt-delivery');
            const pickEl = document.getElementById('opt-takeaway');
            
            // Visual Update
            if (type === 'delivery') {
                // Activate Delivery
                delEl.className = "relative overflow-hidden p-5 rounded-3xl border-2 cursor-pointer transition-all duration-200 bg-brand-light border-brand";
                delEl.querySelector('.ph-check').parentElement.classList.remove('hidden');
                delEl.querySelector('.ph-check').parentElement.classList.add('flex');
                delEl.querySelector('div.bg-white').classList.remove('bg-gray-100', 'text-gray-500');
                delEl.querySelector('div.bg-white').classList.add('text-brand-dark', 'shadow-sm');

                // Deactivate Pickup
                pickEl.className = "relative overflow-hidden p-5 rounded-3xl border-2 border-gray-100 cursor-pointer transition-all duration-200 hover:bg-gray-50";
                document.getElementById('check-takeaway').classList.add('hidden');
                document.getElementById('check-takeaway').classList.remove('flex');
            } else {
                // Activate Pickup
                pickEl.className = "relative overflow-hidden p-5 rounded-3xl border-2 cursor-pointer transition-all duration-200 bg-brand-light border-brand";
                document.getElementById('check-takeaway').classList.remove('hidden');
                document.getElementById('check-takeaway').classList.add('flex');

                // Deactivate Delivery
                delEl.className = "relative overflow-hidden p-5 rounded-3xl border-2 border-gray-100 cursor-pointer transition-all duration-200 hover:bg-gray-50";
                delEl.querySelector('.ph-check').parentElement.classList.add('hidden');
                delEl.querySelector('.ph-check').parentElement.classList.remove('flex');
            }
        }

        function confirmOrderType() {
            closeBottomSheet();
            setTimeout(() => {
                renderDelivery();
            }, 300); // Wait for animation
        }

        // Checkout Logic
        function selectPayment(method) {
            state.paymentMethod = method;
            renderCheckout();
        }

        // Existing Helpers
        function updateQty(index, change) {
            const item = state.cart[index];
            const newQty = item.qty + change;
            if (newQty > 0) {
                item.qty = newQty;
                renderCart();
            } else {
                if(confirm('Remove this item?')) {
                    state.cart.splice(index, 1);
                    renderCart();
                }
            }
        }

        function selectDate(index) {
            state.delivery.selectedDateIndex = index;
            renderDelivery();
        }

        function selectTime(time) {
            state.delivery.selectedTimeSlot = time;
            renderDelivery();
        }

        // Initial Render
        renderCart();

    </script>
</body>
</html>