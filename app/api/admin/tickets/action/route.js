import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';
import { mockAdminTickets } from '../route';

export async function PUT(request) {
    try {
        await verifyAdmin(request);
        const { id, status } = await request.json();

        if (!id || !status) {
            return NextResponse.json({ success: false, message: 'Missing parameters.' });
        }

        if (isMock || !supabase) {
            const idx = mockAdminTickets.findIndex(t => t.id == id);
            if (idx !== -1) {
                mockAdminTickets[idx].status = status;
                return NextResponse.json({ success: true });
            }
            return NextResponse.json({ success: false, message: 'Ticket not found.' });
        }

        const { error } = await supabase
            .from('tickets')
            .update({ status })
            .eq('id', id);

        if (error) throw error;
        return NextResponse.json({ success: true });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 401 });
    }
}
