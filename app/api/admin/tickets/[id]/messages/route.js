import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';

// Shared mock messages database
export let mockAdminTicketMessages = [
    { id: 1, ticket_id: 1, sender_id: 'mock-2', sender_email: 'partner@gmail.com', message: 'Check ticket received', created_at: new Date(Date.now() - 1000 * 60 * 10).toISOString() },
    { id: 2, ticket_id: 2, sender_id: 'mock-2', sender_email: 'partner@gmail.com', message: 'zian test', created_at: new Date(Date.now() - 1000 * 60 * 2).toISOString() }
];

export async function GET(request, { params }) {
    try {
        await verifyAdmin(request);
        const { id } = await params;
        const ticketId = parseInt(id);

        if (isMock || !supabase) {
            const filtered = mockAdminTicketMessages.filter(m => m.ticket_id === ticketId);
            return NextResponse.json({ success: true, messages: filtered });
        }

        const { data: ticket } = await supabase
            .from('tickets')
            .select('status, proof_image')
            .eq('id', ticketId)
            .maybeSingle();

        const { data, error } = await supabase
            .from('ticket_messages')
            .select(`
                id,
                ticket_id,
                sender_id,
                message,
                created_at,
                profiles (
                    email
                )
            `)
            .eq('ticket_id', ticketId)
            .order('created_at', { ascending: true });

        if (error) return NextResponse.json({ success: false, message: error.message });

        const mapped = data.map(m => ({
            id: m.id,
            ticket_id: m.ticket_id,
            sender_id: m.sender_id,
            sender_email: m.profiles ? m.profiles.email : 'System Support',
            message: m.message,
            created_at: m.created_at
        }));

        return NextResponse.json({ 
            success: true, 
            messages: mapped, 
            status: ticket ? ticket.status : 'OPEN', 
            proof_image: ticket ? ticket.proof_image : null 
        });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 401 });
    }
}

export async function POST(request, { params }) {
    try {
        const adminUser = await verifyAdmin(request);
        const { id } = await params;
        const ticketId = parseInt(id);
        const { message } = await request.json();

        if (!message || message.trim() === '') {
            return NextResponse.json({ success: false, message: 'Message cannot be empty.' });
        }

        if (isMock || !supabase) {
            const newMsg = {
                id: mockAdminTicketMessages.length + 1,
                ticket_id: ticketId,
                sender_id: adminUser.id,
                sender_email: adminUser.email,
                message: message.trim(),
                created_at: new Date().toISOString()
            };
            mockAdminTicketMessages.push(newMsg);
            return NextResponse.json({ success: true });
        }

        const { error } = await supabase
            .from('ticket_messages')
            .insert([{
                ticket_id: ticketId,
                sender_id: adminUser.id,
                message: message.trim()
            }]);

        if (error) return NextResponse.json({ success: false, message: error.message });

        return NextResponse.json({ success: true });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 401 });
    }
}
