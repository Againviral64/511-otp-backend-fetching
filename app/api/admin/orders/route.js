import { NextResponse } from 'next/server';
import supabase, { isMock, mockOrders } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';

export async function GET(request) {
    try {
        await verifyAdmin(request);
        const searchParams = new URL(request.url).searchParams;
        const search = searchParams.get('search');
        const startDate = searchParams.get('start_date');
        const endDate = searchParams.get('end_date');

        if (isMock || !supabase) {
            let filtered = mockOrders;
            if (search && search.trim() !== '') {
                const term = search.trim().toLowerCase();
                filtered = filtered.filter(o => 
                    o.user_email.toLowerCase().includes(term) ||
                    o.order_id.toLowerCase().includes(term) ||
                    o.number.includes(term)
                );
            }
            if (startDate) {
                filtered = filtered.filter(o => o.created_at >= startDate);
            }
            const mappedFiltered = filtered.map(o => {
                const priceVal = parseFloat(o.price || 15.04);
                const costVal = priceVal * 0.35; // Mock cost is 35% of selling price
                return {
                    ...o,
                    price: priceVal,
                    cost_price: parseFloat(costVal.toFixed(3)),
                    profit: parseFloat((priceVal - costVal).toFixed(3))
                };
            });
            return NextResponse.json({ success: true, orders: mappedFiltered });
        }

        // Fetch PKR rate from settings
        let pkrRate = 278.50;
        const { data: exchangeRateSetting } = await supabase
            .from('settings')
            .select('value')
            .eq('key', 'exchange_rate_PKR')
            .maybeSingle();
        if (exchangeRateSetting) {
            pkrRate = parseFloat(exchangeRateSetting.value) || 278.50;
        }

        // Fetch services to build cost lookup map
        const { data: services } = await supabase
            .from('services')
            .select('service_id, cost_price');
        const serviceCostMap = {};
        if (services) {
            services.forEach(s => {
                serviceCostMap[s.service_id] = parseFloat(s.cost_price || 0);
            });
        }

        let query = supabase
            .from('orders')
            .select(`
                order_id,
                country,
                service,
                number,
                otp,
                status,
                price,
                sms_url,
                created_at,
                product_id,
                profiles (
                    email
                )
            `);

        // Apply search term filters (email, order_id, phone number)
        if (search && search.trim() !== '') {
            const term = search.trim();
            const { data: matchedProfiles } = await supabase
                .from('profiles')
                .select('id')
                .ilike('email', `%${term}%`);
            
            const profileIds = matchedProfiles ? matchedProfiles.map(p => p.id) : [];
            let orFilter = `number.ilike.%${term}%,order_id.ilike.%${term}%`;
            
            if (profileIds.length > 0) {
                profileIds.forEach(pid => {
                    orFilter += `,user_id.eq.${pid}`;
                });
            }
            query = query.or(orFilter);
        }

        // Apply date range filters in Karachi Timezone
        if (startDate) {
            const startUTC = new Date(`${startDate}T00:00:00+05:00`).toISOString();
            query = query.gte('created_at', startUTC);
        }
        if (endDate) {
            const endUTC = new Date(`${endDate}T23:59:59+05:00`).toISOString();
            query = query.lte('created_at', endUTC);
        }

        const { data, error } = await query
            .order('created_at', { ascending: false })
            .limit(500);

        if (error) {
            console.error('Orders query error:', error.message);
            return NextResponse.json({ success: false, message: error.message });
        }

        const mapped = data.map(o => {
            const usdCost = serviceCostMap[o.product_id] || 0;
            const costPKR = usdCost * pkrRate;
            const pricePKR = parseFloat(o.price || 0);
            const profitPKR = pricePKR - costPKR;

            return {
                order_id: o.order_id,
                country: o.country,
                service: o.service,
                number: o.number,
                otp: o.otp,
                status: o.status === 'CANCELLED' ? 'REFUNDED' : o.status,
                price: pricePKR,
                cost_price: parseFloat(costPKR.toFixed(3)),
                profit: parseFloat(profitPKR.toFixed(3)),
                sms_url: o.sms_url,
                created_at: o.created_at,
                user_email: o.profiles ? o.profiles.email : 'Unknown'
            };
        });

        return NextResponse.json({ success: true, orders: mapped });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 401 });
    }
}
