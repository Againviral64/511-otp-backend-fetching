import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';

export async function GET(request) {
    try {
        await verifyAdmin(request);
        const searchParams = new URL(request.url).searchParams;
        const path = searchParams.get('path');
        if (!path) return NextResponse.json({ success: false, message: 'Missing path parameter' });

        if (isMock || !supabase) {
            return NextResponse.json({ success: true, signedUrl: path });
        }

        const { data, error } = await supabase.storage
            .from('ticket-proofs')
            .createSignedUrl(path, 3600); // 1 hour expiration

        if (error) return NextResponse.json({ success: false, message: error.message });
        return NextResponse.json({ success: true, signedUrl: data.signedUrl });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 401 });
    }
}
