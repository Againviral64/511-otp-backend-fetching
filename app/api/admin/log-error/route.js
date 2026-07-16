import { NextResponse } from 'next/server';

export async function POST(request) {
    try {
        const body = await request.json();
        console.error('🔴 CLIENT-SIDE JAVASCRIPT EXCEPTION CAPTURED:', JSON.stringify(body, null, 2));
        return NextResponse.json({ success: true });
    } catch (e) {
        return NextResponse.json({ success: false });
    }
}
