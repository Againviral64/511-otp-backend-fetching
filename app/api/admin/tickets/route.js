import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';

// Fallback mock database sharing same reference
export let mockAdminTickets = [
    { id: 1, user_id: 'mock-2', title: 'Testing', category: 'OTP', status: 'OPEN', proof_image: null, created_at: new Date(Date.now() - 1000 * 60 * 10).toISOString(), profiles: { name: 'Zain Partner', email: 'partner@gmail.com' } },
    { id: 2, user_id: 'mock-2', title: '67868776576', category: 'OTP', status: 'OPEN', proof_image: null, created_at: new Date(Date.now() - 1000 * 60 * 2).toISOString(), profiles: { name: 'Zain Partner', email: 'partner@gmail.com' } }
];

export async function GET(request) {
    try {
        await verifyAdmin(request);
        const { searchParams } = new URL(request.url);
        const status = searchParams.get('status');
        const search = searchParams.get('search');

        if (isMock || !supabase) {
            let filtered = [...mockAdminTickets];
            if (status) {
                filtered = filtered.filter(t => t.status === status);
            }
            if (search) {
                const s = search.toLowerCase();
                filtered = filtered.filter(t => 
                    t.id.toString().includes(s) || 
                    t.title.toLowerCase().includes(s) || 
                    (t.profiles && t.profiles.email.toLowerCase().includes(s))
                );
            }
            return NextResponse.json({ success: true, tickets: filtered });
        }

        let query = supabase
            .from('tickets')
            .select(`
                *,
                profiles (
                    email,
                    name
                )
            `)
            .order('created_at', { ascending: false });

        if (status) {
            query = query.eq('status', status);
        }

        if (search) {
            // Check if search query is a number (for ID)
            const isIdSearch = /^\d+$/.test(search);
            if (isIdSearch) {
                query = query.or(`id.eq.${search},title.ilike.%${search}%`);
            } else {
                query = query.ilike('title', `%${search}%`);
            }
        }

        const { data, error } = await query;
        if (error) throw error;

        let filteredData = data || [];
        if (search && !/^\d+$/.test(search)) {
            // Apply filtering on the profiles email join if query is text
            filteredData = filteredData.filter(t => 
                t.title.toLowerCase().includes(search.toLowerCase()) ||
                (t.profiles && t.profiles.email.toLowerCase().includes(search.toLowerCase())) ||
                (t.profiles && t.profiles.name && t.profiles.name.toLowerCase().includes(search.toLowerCase()))
            );
        }

        return NextResponse.json({ success: true, tickets: filteredData });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 401 });
    }
}
