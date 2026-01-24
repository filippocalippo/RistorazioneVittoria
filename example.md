<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Luigi's Driver Pro</title>
    
    <!-- Tailwind CSS -->
    <script src="https://cdn.tailwindcss.com"></script>
    
    <!-- Font Awesome -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">

    <!-- Google Fonts -->
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800&display=swap" rel="stylesheet">

    <!-- Leaflet CSS -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />

    <!-- Leaflet JS -->
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>

    <script>
        tailwind.config = {
            theme: {
                extend: {
                    fontFamily: { sans: ['Inter', 'sans-serif'] },
                    colors: {
                        brand: {
                            50: '#ecfdf5',
                            100: '#d1fae5',
                            200: '#a7f3d0',
                            500: '#10b981',
                            600: '#059669', // Elegant Green
                            700: '#047857',
                            800: '#065f46',
                            900: '#064e3b',
                        }
                    },
                    boxShadow: {
                        'up': '0 -4px 20px -5px rgba(0, 0, 0, 0.1)',
                    }
                }
            }
        }
    </script>

    <style>
        /* Mobile Optimizations */
        body {
            -webkit-tap-highlight-color: transparent;
            overscroll-behavior-y: none;
            background-color: #f8fafc;
        }

        /* Animations */
        .screen {
            display: none;
            height: 100vh;
            width: 100vw;
            flex-direction: column;
            animation: fadeIn 0.3s ease-out;
        }
        
        .screen.active {
            display: flex;
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        /* Slider Component */
        .slider-container {
            position: relative;
            width: 100%;
            height: 56px;
            background: #f3f4f6;
            border-radius: 999px;
            overflow: hidden;
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.05);
        }
        
        .slider-text {
            font-weight: 600;
            color: #9ca3af;
            letter-spacing: 0.5px;
            pointer-events: none;
            transition: opacity 0.3s;
        }

        .slider-thumb {
            position: absolute;
            left: 4px;
            width: 48px;
            height: 48px;
            background: #059669;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-size: 20px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2);
            cursor: grab;
            touch-action: none;
            z-index: 10;
        }

        .completed-bg {
            position: absolute;
            left: 0; top: 0; bottom: 0; width: 0%;
            background: #059669;
            z-index: 1;
        }

        /* Flashlight Mode */
        .flashlight-mode {
            background-color: white !important;
            z-index: 9999;
        }
        .flashlight-mode * {
            display: none !important;
        }
        .flashlight-mode::after {
            content: 'Tap to turn off';
            display: block !important;
            position: fixed;
            top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            color: black; font-size: 1.5rem; font-weight: bold;
            text-transform: uppercase;
        }

        /* Expansion Animations */
        .order-details {
            max-height: 0;
            overflow: hidden;
            transition: max-height 0.3s ease-out, opacity 0.3s ease-out;
            opacity: 0;
        }
        .card-expanded .order-details {
            max-height: 600px;
            opacity: 1;
        }
        .card-expanded .chevron { transform: rotate(180deg); }

        /* Map Containers */
        .map-container { height: 100%; width: 100%; }
    </style>
</head>
<body class="text-gray-800 h-screen overflow-hidden select-none">

    <!-- ======================================================================= -->
    <!-- SCREEN 1: DASHBOARD (LIST VIEW) -->
    <!-- ======================================================================= -->
    <div id="screen-dashboard" class="screen active bg-gray-50">
        <!-- Header -->
        <header class="bg-white px-5 pt-12 pb-4 shadow-sm z-20 flex-shrink-0">
            <div class="flex justify-between items-start">
                <div>
                    <h1 class="text-2xl font-extrabold text-gray-900 tracking-tight">My Route</h1>
                    <p class="text-xs text-gray-500 font-medium mt-1"><span id="queue-count">0</span> Orders • Est. 45 mins</p>
                </div>
                <div class="flex flex-col items-end">
                    <div class="flex items-center gap-2 bg-gray-50 px-2 py-1 rounded-lg border border-gray-100">
                        <i class="fa-solid fa-cloud-rain text-blue-400"></i>
                        <span class="text-xs font-bold text-gray-600">Rainy</span>
                    </div>
                </div>
            </div>

            <!-- Money Stats -->
            <div class="grid grid-cols-2 gap-3 mt-4">
                <div class="bg-brand-50 border border-brand-100 p-3 rounded-xl flex flex-col">
                    <span class="text-[10px] uppercase text-brand-700 font-bold tracking-wider">Tips Earned</span>
                    <span class="text-xl font-bold text-brand-700" id="dash-tips">$24.50</span>
                </div>
                <div class="bg-amber-50 border border-amber-100 p-3 rounded-xl flex flex-col relative overflow-hidden">
                    <span class="text-[10px] uppercase text-amber-700 font-bold tracking-wider">Cash in Hand</span>
                    <span class="text-xl font-bold text-amber-800" id="dash-cash">$0.00</span>
                    <i class="fa-solid fa-wallet absolute -bottom-2 -right-2 text-4xl text-amber-100 -z-0"></i>
                </div>
            </div>
        </header>

        <!-- Content List -->
        <main class="flex-1 overflow-y-auto p-4 space-y-4 pb-24 custom-scroll" id="order-list-container">
            <!-- JS Injects Orders Here -->
        </main>

        <!-- Bottom Nav -->
        <nav class="bg-white border-t border-gray-200 h-20 pb-6 px-6 flex justify-between items-center z-30 flex-shrink-0">
            <button class="flex flex-col items-center gap-1 text-brand-600">
                <i class="fa-solid fa-list-check text-xl"></i>
                <span class="text-[10px] font-bold">Queue</span>
            </button>
            <button onclick="switchToGlobalMap()" class="flex flex-col items-center gap-1 text-gray-400 hover:text-brand-600 transition-colors relative">
                <div class="absolute -top-1 -right-1 w-2 h-2 bg-brand-500 rounded-full"></div>
                <i class="fa-solid fa-map text-xl"></i>
                <span class="text-[10px] font-bold">Map View</span>
            </button>
            <button class="flex flex-col items-center gap-1 text-gray-400 hover:text-gray-600">
                <i class="fa-solid fa-gear text-xl"></i>
                <span class="text-[10px] font-bold">Settings</span>
            </button>
        </nav>
    </div>

    <!-- ======================================================================= -->
    <!-- SCREEN 2: GLOBAL MAP VIEW -->
    <!-- ======================================================================= -->
    <div id="screen-global-map" class="screen relative">
        <div id="map-global" class="map-container"></div>
        
        <!-- Floating Back Button -->
        <button onclick="switchToDashboard()" class="absolute top-12 left-4 z-[1000] bg-white text-gray-800 px-4 py-2 rounded-full shadow-lg font-bold text-sm flex items-center gap-2">
            <i class="fa-solid fa-arrow-left"></i> List View
        </button>

        <!-- Floating Bottom Summary (Dynamic) -->
        <div id="map-preview-card" class="absolute bottom-6 left-4 right-4 bg-white p-4 rounded-2xl shadow-2xl z-[1000] hidden transition-all duration-300 transform translate-y-0">
            <div class="flex justify-between items-start">
                <div>
                    <h3 class="font-bold text-lg" id="map-card-address">Address</h3>
                    <p class="text-sm text-gray-500" id="map-card-dist">Distance</p>
                </div>
                <div class="text-right">
                    <div class="font-bold text-gray-900" id="map-card-price">$0.00</div>
                    <div class="text-[10px] font-bold px-2 py-0.5 rounded bg-gray-100 text-gray-600 inline-block mt-1" id="map-card-pay">Type</div>
                </div>
            </div>
            <button id="map-card-btn" class="w-full mt-3 py-2.5 bg-brand-600 text-white rounded-xl font-bold shadow-lg shadow-brand-200 active:scale-95 transition-transform">
                Select Order
            </button>
        </div>
    </div>

    <!-- ======================================================================= -->
    <!-- SCREEN 3: ACTIVE DELIVERY (NAVIGATION) -->
    <!-- ======================================================================= -->
    <div id="screen-active" class="screen relative">
        <div id="map-active" class="absolute inset-0 z-0"></div>

        <!-- Floating Tools -->
        <div class="absolute top-12 right-4 flex flex-col gap-3 z-[1000]">
            <button onclick="toggleFlashlight()" class="w-12 h-12 bg-white rounded-full shadow-lg flex items-center justify-center text-gray-700 active:scale-95">
                <i class="fa-solid fa-lightbulb"></i>
            </button>
            <button onclick="centerActiveMap()" class="w-12 h-12 bg-white rounded-full shadow-lg flex items-center justify-center text-brand-600 active:scale-95">
                <i class="fa-solid fa-location-crosshairs text-lg"></i>
            </button>
        </div>

        <!-- Active Order Sheet -->
        <div class="absolute bottom-0 left-0 right-0 bg-white rounded-t-3xl shadow-up z-[1001] flex flex-col transition-all duration-300" id="active-sheet">
            <!-- Handle -->
            <div class="w-full flex justify-center pt-3 pb-1 cursor-pointer" onclick="toggleActiveDetails()">
                <div class="w-12 h-1.5 bg-gray-300 rounded-full"></div>
            </div>

            <!-- Header Info -->
            <div class="px-6 pb-4 pt-2">
                <div class="flex justify-between items-start mb-2">
                    <div>
                        <span class="bg-brand-100 text-brand-800 text-[10px] font-bold px-2 py-0.5 rounded uppercase tracking-wide">Current Delivery</span>
                        <h2 class="text-xl font-extrabold text-gray-900 leading-tight mt-1" id="active-address">Address</h2>
                        <p class="text-sm text-gray-500 font-medium" id="active-customer">Customer Name</p>
                    </div>
                    <div class="flex flex-col items-end">
                        <div class="text-xl font-bold text-gray-900" id="active-price">$0.00</div>
                        <div id="active-cash-badge" class="hidden flex items-center gap-1 text-amber-600 bg-amber-50 px-2 py-0.5 rounded text-[10px] font-bold border border-amber-100 mt-1">
                            <i class="fa-solid fa-hand-holding-dollar"></i> CASH
                        </div>
                    </div>
                </div>

                <!-- Quick Actions Grid -->
                <div class="grid grid-cols-4 gap-3 mt-4">
                    <button class="flex flex-col items-center gap-1 group" onclick="window.open('https://maps.google.com', '_blank')">
                        <div class="w-12 h-12 rounded-2xl bg-blue-50 text-blue-600 flex items-center justify-center text-xl group-active:bg-blue-100">
                            <i class="fa-solid fa-location-arrow"></i>
                        </div>
                        <span class="text-[10px] font-semibold text-gray-600">Map</span>
                    </button>
                    <button class="flex flex-col items-center gap-1 group" onclick="window.location.href='tel:555'">
                        <div class="w-12 h-12 rounded-2xl bg-green-50 text-green-600 flex items-center justify-center text-xl group-active:bg-green-100">
                            <i class="fa-solid fa-phone"></i>
                        </div>
                        <span class="text-[10px] font-semibold text-gray-600">Call</span>
                    </button>
                    <button class="flex flex-col items-center gap-1 group" onclick="toggleMsgModal(true)">
                        <div class="w-12 h-12 rounded-2xl bg-purple-50 text-purple-600 flex items-center justify-center text-xl group-active:bg-purple-100">
                            <i class="fa-solid fa-comment-dots"></i>
                        </div>
                        <span class="text-[10px] font-semibold text-gray-600">Text</span>
                    </button>
                    <button class="flex flex-col items-center gap-1 group" onclick="toggleActiveDetails()">
                        <div class="w-12 h-12 rounded-2xl bg-gray-50 text-gray-600 flex items-center justify-center text-xl group-active:bg-gray-200">
                            <i class="fa-solid fa-list-ul"></i>
                        </div>
                        <span class="text-[10px] font-semibold text-gray-600">Items</span>
                    </button>
                </div>
            </div>

            <!-- Expanded Content (Items & Notes) -->
            <div id="active-details-content" class="hidden flex-1 overflow-y-auto bg-gray-50 border-t border-gray-100 p-6 h-64">
                 <div class="bg-yellow-50 border border-yellow-100 rounded-xl p-4 mb-4 shadow-sm">
                    <h3 class="text-xs font-bold text-yellow-800 uppercase mb-1"><i class="fa-solid fa-note-sticky mr-1"></i> Note</h3>
                    <p class="text-sm text-gray-800 font-medium" id="active-note">No notes.</p>
                </div>
                <div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">
                    <h3 class="text-xs font-bold text-gray-400 uppercase mb-3">Order Items</h3>
                    <ul class="space-y-3" id="active-items-list">
                        <!-- Items Injected -->
                    </ul>
                </div>
            </div>

            <!-- Slider Area -->
            <div class="p-5 bg-white border-t border-gray-100 z-10">
                <div class="slider-container" id="swipe-slider">
                    <div class="completed-bg" id="slider-bg"></div>
                    <div class="slider-text" id="slider-text">Slide to Complete</div>
                    <div class="slider-thumb" id="slider-thumb">
                        <i class="fa-solid fa-chevron-right"></i>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <!-- Quick Message Modal -->
    <div id="msg-modal" class="fixed inset-0 bg-black/60 z-[2000] hidden flex items-end justify-center animate-fade-in">
        <div class="bg-white w-full rounded-t-3xl p-6 pb-10">
            <div class="flex justify-between items-center mb-5">
                <h3 class="text-lg font-bold text-gray-900">Quick Message</h3>
                <button onclick="toggleMsgModal(false)" class="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center text-gray-500"><i class="fa-solid fa-times"></i></button>
            </div>
            <div class="space-y-3">
                <button onclick="sendMsg(this)" class="w-full text-left px-4 py-3 bg-gray-50 rounded-xl font-medium text-gray-700 flex items-center gap-3 border border-gray-200"><i class="fa-regular fa-clock text-brand-500"></i> "I'm 5 minutes away."</button>
                <button onclick="sendMsg(this)" class="w-full text-left px-4 py-3 bg-gray-50 rounded-xl font-medium text-gray-700 flex items-center gap-3 border border-gray-200"><i class="fa-solid fa-road text-brand-500"></i> "I've arrived."</button>
            </div>
        </div>
    </div>

    <script>
        // --- DATA MODEL ---
        const DRIVER_START = [40.7128, -74.0060];
        
        const state = {
            earned: 24.50,
            cashInHand: 0.00,
            currentOrder: null,
            orders: [
                {
                    id: 101,
                    customer: "John Doe",
                    address: "789 Broadway Ave",
                    dist: "2.4 km",
                    time: "12 min",
                    price: "$45.00",
                    paymentType: "CASH",
                    note: "Gate code 1234. Ring twice.",
                    lat: 40.7150, lng: -73.9900,
                    items: [
                        { qty: 1, name: "Lrg Pepperoni" },
                        { qty: 2, name: "Garlic Knots" },
                        { qty: 1, name: "Cola (2L)", critical: true }
                    ]
                },
                {
                    id: 102,
                    customer: "Alice Smith",
                    address: "124 West St",
                    dist: "4.1 km",
                    time: "25 min",
                    price: "$32.00",
                    paymentType: "PAID",
                    note: "Leave at door.",
                    lat: 40.7200, lng: -74.0100,
                    items: [
                        { qty: 2, name: "Margherita" },
                        { qty: 1, name: "Tiramisu", critical: true }
                    ]
                },
                {
                    id: 103,
                    customer: "Bob Brown",
                    address: "550 Park Ave",
                    dist: "5.2 km",
                    time: "35 min",
                    price: "$55.50",
                    paymentType: "PAID",
                    note: "Do not ring bell. Baby sleeping.",
                    lat: 40.7300, lng: -73.9950,
                    items: [
                        { qty: 3, name: "Veggie Special" },
                        { qty: 2, name: "Fanta" }
                    ]
                }
            ]
        };

        // --- MAPS ---
        let globalMap, activeMap, activeRouteLine;

        window.onload = function() {
            renderDashboard();
            initGlobalMap(); // Pre-load map
        };

        // --- DASHBOARD LOGIC ---
        function renderDashboard() {
            document.getElementById('queue-count').innerText = state.orders.length;
            document.getElementById('dash-tips').innerText = `$${state.earned.toFixed(2)}`;
            document.getElementById('dash-cash').innerText = `$${state.cashInHand.toFixed(2)}`;

            const container = document.getElementById('order-list-container');
            container.innerHTML = '';

            if(state.orders.length === 0) {
                container.innerHTML = `<div class="text-center text-gray-400 mt-10"><i class="fa-solid fa-check-circle text-4xl mb-2"></i><p>All caught up!</p></div>`;
                return;
            }

            // Header for queue
            container.innerHTML = `<div class="flex justify-between items-end px-1 mb-2"><h2 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Priority Queue</h2></div>`;

            state.orders.forEach((order, index) => {
                const isNext = index === 0;
                const isCash = order.paymentType === 'CASH';
                
                // Items HTML for checklist
                let checklistHtml = '';
                order.items.forEach((item, i) => {
                    const criticalClass = item.critical ? 'font-bold text-brand-600' : 'text-gray-600';
                    const icon = item.critical ? '<i class="fa-solid fa-triangle-exclamation ml-1 text-brand-500"></i>' : '';
                    checklistHtml += `
                        <label class="flex items-center gap-3 cursor-pointer group py-1">
                            <input type="checkbox" class="hidden peer" onchange="checkReadiness(${order.id})">
                            <div class="w-5 h-5 rounded border-2 border-gray-300 bg-white flex items-center justify-center transition-colors peer-checked:bg-brand-500 peer-checked:border-brand-500 text-white text-xs">
                                <i class="fa-solid fa-check"></i>
                            </div>
                            <span class="text-sm ${criticalClass} peer-checked:text-gray-400 peer-checked:line-through transition-colors">${item.qty}x ${item.name} ${icon}</span>
                        </label>
                    `;
                });

                const card = document.createElement('div');
                card.className = `bg-white rounded-2xl shadow-sm border ${isNext ? 'border-2 border-brand-500' : 'border-gray-100'} relative overflow-hidden card-container transition-all duration-300 mb-4`;
                card.id = `card-${order.id}`;
                
                card.innerHTML = `
                    ${isNext ? `<div class="bg-brand-500 text-white text-[10px] font-bold px-3 py-1 absolute top-0 left-0 rounded-br-lg z-10 animate-pulse">RECOMMENDED NEXT</div>` : ''}
                    
                    <div class="p-5 ${isNext ? 'pt-7' : ''} cursor-pointer" onclick="toggleCard(${order.id})">
                        <div class="flex justify-between items-start">
                            <div class="flex items-center gap-3">
                                <div class="w-10 h-10 rounded-full ${isNext ? 'bg-brand-50 text-brand-700 border-brand-100' : 'bg-gray-50 text-gray-400 border-gray-100'} flex items-center justify-center font-bold border">
                                    ${index + 1}
                                </div>
                                <div>
                                    <h3 class="font-bold text-lg text-gray-900">${order.address}</h3>
                                    <div class="flex items-center gap-2 text-sm text-gray-500">
                                        ${isNext ? `<i class="fa-solid fa-clock text-orange-500"></i> <span class="font-medium text-orange-600">Due in ${order.time}</span>` : `<span>${order.dist}</span>`}
                                        <span>•</span>
                                        <span class="${isCash ? 'text-amber-600 font-bold' : 'text-green-600 font-bold'}">${order.paymentType}</span>
                                    </div>
                                </div>
                            </div>
                            <i class="fa-solid fa-chevron-down text-gray-300 transition-transform duration-300 chevron"></i>
                        </div>
                    </div>

                    <div class="order-details bg-gray-50 border-t border-gray-100">
                        <div class="p-5">
                            ${isCash ? `<div class="flex items-center gap-2 bg-amber-100 text-amber-800 px-3 py-2 rounded-lg text-xs font-bold mb-4 border border-amber-200"><i class="fa-solid fa-hand-holding-dollar"></i> COLLECT CASH: ${order.price}</div>` : ''}
                            
                            <div class="mb-5">
                                <h4 class="text-[10px] uppercase text-gray-400 font-bold mb-2">Cargo Checklist</h4>
                                <div class="space-y-1">${checklistHtml}</div>
                            </div>

                            <button id="btn-${order.id}" onclick="startDelivery(${order.id})" class="w-full py-3.5 rounded-xl bg-gray-200 text-gray-400 font-bold shadow-sm transition-all duration-300 flex items-center justify-center gap-2 pointer-events-none">
                                <i class="fa-solid fa-lock"></i> Verify Items First
                            </button>
                        </div>
                    </div>
                `;
                container.appendChild(card);
            });
        }

        function toggleCard(id) {
            const card = document.getElementById(`card-${id}`);
            const wasOpen = card.classList.contains('card-expanded');
            
            // Close all
            document.querySelectorAll('.card-container').forEach(c => c.classList.remove('card-expanded'));
            
            // Toggle clicked
            if (!wasOpen) card.classList.add('card-expanded');
        }

        function checkReadiness(id) {
            const card = document.getElementById(`card-${id}`);
            const checkboxes = card.querySelectorAll('input[type="checkbox"]');
            const btn = document.getElementById(`btn-${id}`);
            const allChecked = Array.from(checkboxes).every(cb => cb.checked);

            if(allChecked) {
                btn.classList.remove('bg-gray-200', 'text-gray-400', 'pointer-events-none');
                btn.classList.add('bg-brand-600', 'text-white', 'shadow-lg', 'shadow-brand-200', 'active:scale-95');
                btn.innerHTML = `<i class="fa-solid fa-location-arrow animate-bounce"></i> START DELIVERY`;
            } else {
                btn.classList.add('bg-gray-200', 'text-gray-400', 'pointer-events-none');
                btn.classList.remove('bg-brand-600', 'text-white', 'shadow-lg');
                btn.innerHTML = `<i class="fa-solid fa-lock"></i> Verify Items First`;
            }
        }

        // --- NAVIGATION & SCREENS ---
        
        function switchToGlobalMap() {
            document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
            document.getElementById('screen-global-map').classList.add('active');
            setTimeout(() => {
                if(!globalMap) initGlobalMap();
                globalMap.invalidateSize(); // Vital for Leaflet render in hidden div
                renderGlobalPins();
            }, 100);
        }

        function switchToDashboard() {
            document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
            document.getElementById('screen-dashboard').classList.add('active');
        }

        function startDelivery(id) {
            const order = state.orders.find(o => o.id === id);
            state.currentOrder = order;
            
            document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
            document.getElementById('screen-active').classList.add('active');
            
            // Populate Active Screen Data
            document.getElementById('active-address').innerText = order.address;
            document.getElementById('active-customer').innerText = order.customer;
            document.getElementById('active-price').innerText = order.price;
            document.getElementById('active-note').innerText = order.note;
            
            // Cash Badge
            const cashBadge = document.getElementById('active-cash-badge');
            if(order.paymentType === 'CASH') cashBadge.classList.remove('hidden');
            else cashBadge.classList.add('hidden');

            // Items List
            const itemsList = document.getElementById('active-items-list');
            itemsList.innerHTML = '';
            order.items.forEach(item => {
                itemsList.innerHTML += `<li class="flex items-center gap-3"><div class="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center text-gray-500 text-xs font-bold">${item.qty}x</div><span class="text-sm font-medium text-gray-700">${item.name}</span></li>`;
            });

            // Init Map logic
            setTimeout(() => initActiveMap(order), 100);
        }

        // --- GLOBAL MAP LOGIC ---
        function initGlobalMap() {
            globalMap = L.map('map-global', { zoomControl: false }).setView(DRIVER_START, 13);
            L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png').addTo(globalMap);
            
            // Driver Pin
            L.marker(DRIVER_START, {
                icon: L.divIcon({
                    className: '',
                    html: `<div class="w-8 h-8 bg-blue-600 border-4 border-white rounded-full shadow-lg flex items-center justify-center"><i class="fa-solid fa-car text-white text-[10px]"></i></div>`,
                    iconSize: [32, 32]
                })
            }).addTo(globalMap);
        }

        function renderGlobalPins() {
            // Clear existing pins (omitted for brevity in this single file version, assume fresh render)
            state.orders.forEach(order => {
                const color = order.paymentType === 'CASH' ? '#d97706' : '#059669';
                const icon = L.divIcon({
                    className: '',
                    html: `<div style="background:${color}" class="w-8 h-8 border-2 border-white rounded-full shadow-lg flex items-center justify-center text-white text-xs font-bold">${order.id % 100}</div>`,
                    iconSize: [32, 32]
                });
                
                const marker = L.marker([order.lat, order.lng], { icon }).addTo(globalMap);
                marker.on('click', () => {
                    showMapPreview(order);
                });
            });
        }

        function showMapPreview(order) {
            const card = document.getElementById('map-preview-card');
            card.classList.remove('hidden', 'translate-y-10');
            
            document.getElementById('map-card-address').innerText = order.address;
            document.getElementById('map-card-dist').innerText = `${order.dist} • ${order.time}`;
            document.getElementById('map-card-price').innerText = order.price;
            document.getElementById('map-card-pay').innerText = order.paymentType;
            
            // Logic to jump to that order in list
            document.getElementById('map-card-btn').onclick = () => {
                switchToDashboard();
                setTimeout(() => {
                    const el = document.getElementById(`card-${order.id}`);
                    el.scrollIntoView({ behavior: 'smooth' });
                    toggleCard(order.id);
                }, 300);
            };
        }

        // --- ACTIVE MAP LOGIC ---
        function initActiveMap(order) {
            if(activeMap) {
                activeMap.remove(); // Reset map instance
            }

            activeMap = L.map('map-active', { zoomControl: false }).setView(DRIVER_START, 15);
            L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png').addTo(activeMap);

            // Driver
            L.marker(DRIVER_START, {
                icon: L.divIcon({
                    html: `<div class="w-10 h-10 bg-brand-600 border-4 border-white rounded-full shadow-xl flex items-center justify-center"><i class="fa-solid fa-location-arrow text-white text-sm transform -rotate-45"></i></div>`,
                    iconSize: [40, 40]
                })
            }).addTo(activeMap);

            // Destination
            L.marker([order.lat, order.lng], {
                icon: L.divIcon({
                    html: `<div class="w-8 h-8 bg-gray-900 border-4 border-white rounded-full shadow-lg flex items-center justify-center animate-bounce"><i class="fa-solid fa-flag-checkered text-white text-xs"></i></div>`,
                    iconSize: [32, 32]
                })
            }).addTo(activeMap);

            // Route
            const bounds = L.latLngBounds(DRIVER_START, [order.lat, order.lng]);
            L.polyline([DRIVER_START, [40.714, -74.000], [order.lat, order.lng]], {
                color: '#059669', weight: 6, opacity: 0.8
            }).addTo(activeMap);
            
            activeMap.fitBounds(bounds, { padding: [50, 50] });
        }

        function centerActiveMap() {
            if(state.currentOrder && activeMap) {
                const bounds = L.latLngBounds(DRIVER_START, [state.currentOrder.lat, state.currentOrder.lng]);
                activeMap.fitBounds(bounds, { padding: [50, 50] });
            }
        }

        // --- SLIDER & COMPLETION ---
        const slider = document.getElementById('swipe-slider');
        const thumb = document.getElementById('slider-thumb');
        const bg = document.getElementById('slider-bg');
        const text = document.getElementById('slider-text');
        
        let isDragging = false, startX = 0;
        const maxDrag = slider.offsetWidth - thumb.offsetWidth - 8;

        thumb.addEventListener('touchstart', (e) => { isDragging = true; startX = e.touches[0].clientX; thumb.style.transition = 'none'; bg.style.transition = 'none'; });
        thumb.addEventListener('mousedown', (e) => { isDragging = true; startX = e.clientX; thumb.style.transition = 'none'; bg.style.transition = 'none'; });

        const dragMove = (e) => {
            if(!isDragging) return;
            const x = (e.type === 'touchmove' ? e.touches[0].clientX : e.clientX);
            let delta = Math.max(0, Math.min(x - startX, maxDrag));
            thumb.style.transform = `translateX(${delta}px)`;
            bg.style.width = `${(delta/maxDrag)*100}%`;
            text.style.opacity = 1 - (delta/(maxDrag*0.6));
            
            if(delta >= maxDrag * 0.9) completeOrder();
        };

        const dragEnd = () => {
            if(!isDragging) return;
            isDragging = false;
            thumb.style.transition = '0.3s'; bg.style.transition = '0.3s';
            if(thumb.style.transform.includes(`${maxDrag}px`)) return; // Already done
            thumb.style.transform = 'translateX(0)'; bg.style.width = '0%'; text.style.opacity = 1;
        };

        document.addEventListener('touchmove', dragMove); document.addEventListener('mousemove', dragMove);
        document.addEventListener('touchend', dragEnd); document.addEventListener('mouseup', dragEnd);

        function completeOrder() {
            isDragging = false; // Stop logic
            thumb.style.transform = `translateX(${maxDrag}px)`;
            bg.style.width = '100%';
            thumb.innerHTML = '<i class="fa-solid fa-check"></i>';
            
            // Update State
            if(state.currentOrder.paymentType === 'CASH') {
                state.cashInHand += parseFloat(state.currentOrder.price.replace('$',''));
            }
            state.orders = state.orders.filter(o => o.id !== state.currentOrder.id);
            
            setTimeout(() => {
                alert(`Delivered! Earned ${state.currentOrder.price}`);
                // Reset UI
                thumb.style.transform = 'translateX(0)'; bg.style.width = '0%'; thumb.innerHTML = '<i class="fa-solid fa-chevron-right"></i>'; text.style.opacity = 1;
                
                switchToDashboard();
                renderDashboard();
            }, 800);
        }

        // --- UTILS ---
        function toggleFlashlight() { document.body.classList.toggle('flashlight-mode'); }
        function toggleActiveDetails() {
            const sheet = document.getElementById('active-sheet');
            const content = document.getElementById('active-details-content');
            content.classList.toggle('hidden');
            // Simple visual toggle
        }
        function toggleMsgModal(show) {
            const modal = document.getElementById('msg-modal');
            if(show) modal.classList.remove('hidden');
            else modal.classList.add('hidden');
        }
        function sendMsg(btn) {
            const original = btn.innerHTML;
            btn.innerHTML = '<i class="fa-solid fa-check text-brand-600"></i> Sent!';
            setTimeout(() => { toggleMsgModal(false); setTimeout(() => btn.innerHTML = original, 500); }, 800);
        }

    </script>
</body>
</html>