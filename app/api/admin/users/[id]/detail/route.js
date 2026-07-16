import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';

export async function GET(request, { params }) {
    try {
        await verifyAdmin(request);
        const { id } = await params;

        if (!id) {
            return NextResponse.json({ success: false, message: 'Missing user ID parameter.' }, { status: 400 });
        }

        if (isMock || !supabase) {
            // Return mock detail data
            return NextResponse.json({
                success: true,
                profile: { 
                    id, 
                    email: 'partner@gmail.com', 
                    name: 'Zain Partner', 
                    balance: 120.00, 
                    spend: 320.00, 
                    total_orders: 15, 
                    role: 'user', 
                    status: 'ACTIVE',
                    created_at: new Date().toISOString()
                },
                stats: {
                    lifetime_orders: 15,
                    lifetime_deposits: 440.00,
                    today_orders: 2,
                    today_deposits: 0.00
                },
                orders: [
                    { order_id: 'MOCK-1', country: 'United States', service: 'Telegram', number: '+1234567890', otp: '12345', price: 12.00, status: 'COMPLETED', created_at: new Date().toISOString(), sms_url: null },
                    { order_id: 'MOCK-2', country: 'United States', service: 'WhatsApp', number: '+1234567891', otp: null, price: 15.00, status: 'PENDING', created_at: new Date().toISOString(), sms_url: null }
                ],
                deposits: [
                    { id: 1, method: 'Easypaisa', amount: 440.00, currency: 'PKR', tx_id: 'TX12345', status: 'APPROVED', created_at: new Date().toISOString(), payment_note: 'Direct Transfer' }
                ]
            });
        }

        // 1. Fetch user profile details
        const { data: profile, error: profileErr } = await supabase
            .from('profiles')
            .select('*')
            .eq('id', id)
            .maybeSingle();

        if (profileErr || !profile) {
            return NextResponse.json({ success: false, message: 'User profile not found.' }, { status: 404 });
        }

        // 2. Fetch all orders for this user
        const { data: orders, error: ordersErr } = await supabase
            .from('orders')
            .select('*')
            .eq('user_id', id)
            .order('created_at', { ascending: false });

        if (ordersErr) throw ordersErr;

        // 3. Fetch all deposits for this user
        const { data: deposits, error: depositsErr } = await supabase
            .from('deposits')
            .select('*')
            .eq('user_id', id)
            .order('created_at', { ascending: false });

        if (depositsErr) throw depositsErr;

        // 4. Load exchange rates dynamically from settings for deposit calculations
        const exchangeRates = {
            PKR: 278.50,
            USD: 1.0,
            INR: 83.40,
            BDT: 117.20,
            NPR: 133.50,
            RUB: 88.30
        };

        const { data: dbSettings } = await supabase
            .from('settings')
            .select('key, value');

        if (dbSettings) {
            dbSettings.forEach(s => {
                if (s.key.startsWith('exchange_rate_')) {
                    const curr = s.key.replace('exchange_rate_', '');
                    const val = parseFloat(s.value);
                    if (!isNaN(val)) {
                        exchangeRates[curr] = val;
                    }
                }
            });
        }

        const pkrRate = exchangeRates['PKR'] || 278.50;
        const todayStr = new Date().toISOString().split('T')[0];

        // 5. Calculate statistics
        let todayOrdersCount = 0;
        let todayDepositsSum = 0;
        let lifetimeDepositsSum = 0;

        // Process orders
        orders.forEach(o => {
            const orderDateStr = new Date(o.created_at).toISOString().split('T')[0];
            if (orderDateStr === todayStr) {
                todayOrdersCount++;
            }
        });

        // Process deposits
        const mappedDeposits = deposits.map(d => {
            const currency = d.currency || 'USD';
            const rate = exchangeRates[currency] || 1.0;
            const amtInPkr = parseFloat(d.amount) * (pkrRate / rate);

            if (d.status === 'APPROVED') {
                lifetimeDepositsSum += amtInPkr;
                const depDateStr = new Date(d.created_at).toISOString().split('T')[0];
                if (depDateStr === todayStr) {
                    todayDepositsSum += amtInPkr;
                }
            }

            return {
                id: d.id,
                method: d.method,
                amount: d.amount,
                currency: currency,
                amount_pkr: amtInPkr,
                tx_id: d.account_name !== undefined ? d.account_name : d.tx_id,
                status: d.status,
                created_at: d.created_at,
                proof_image: d.proof_image || d.screenshot_url || null,
                payment_note: d.payment_note || null
            };
        });

        const mappedOrders = orders.map(o => ({
            order_id: o.order_id,
            country: o.country,
            service: o.service,
            number: o.number,
            otp: o.otp,
            status: o.status === 'CANCELLED' ? 'REFUNDED' : o.status,
            price: o.price,
            sms_url: o.sms_url,
            created_at: o.created_at
        }));

        return NextResponse.json({
            success: true,
            profile,
            stats: {
                lifetime_orders: orders.length,
                lifetime_deposits: parseFloat(lifetimeDepositsSum.toFixed(3)),
                today_orders: todayOrdersCount,
                today_deposits: parseFloat(todayDepositsSum.toFixed(3))
            },
            orders: mappedOrders,
            deposits: mappedDeposits
        });

    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 500 });
    }
}
