import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAdmin } from '@/lib/middleware';

export async function GET(request) {
    try {
        await verifyAdmin(request);

        if (isMock || !supabase) {
            return NextResponse.json({
                success: true,
                otp_expiry_duration: 5,
                tracking_domain: 'access.novatixdigi.online'
            });
        }

        const { data: configRows } = await supabase
            .from('settings')
            .select('key, value')
            .in('key', ['otp_expiry_duration', 'tracking_domain']);

        let duration = 4;
        let domain = 'access.novatixdigi.online';

        if (configRows) {
            const expRow = configRows.find(r => r.key === 'otp_expiry_duration');
            const trkRow = configRows.find(r => r.key === 'tracking_domain');
            if (expRow && expRow.value) duration = parseInt(expRow.value) || 4;
            if (trkRow && trkRow.value) domain = trkRow.value.trim();
        }

        return NextResponse.json({
            success: true,
            otp_expiry_duration: duration,
            tracking_domain: domain
        });
    } catch (e) {
        return NextResponse.json({ success: false, message: 'Failed to retrieve settings: ' + e.message }, { status: 500 });
    }
}

export async function POST(request) {
    try {
        await verifyAdmin(request);
        const { duration, tracking_domain } = await request.json();
        const durationVal = parseInt(duration);

        if (isNaN(durationVal) || durationVal < 1) {
            return NextResponse.json({ success: false, message: 'Please specify a valid positive countdown timeout duration in minutes.' });
        }

        const domainVal = (tracking_domain || 'access.novatixdigi.online').trim().replace(/^https?:\/\//, '').replace(/\/$/, '');

        if (isMock || !supabase) {
            return NextResponse.json({ success: true, message: 'Mock settings updated.' });
        }

        // Upsert otp_expiry_duration
        const { error: expErr } = await supabase
            .from('settings')
            .upsert({ key: 'otp_expiry_duration', value: durationVal.toString() }, { onConflict: 'key' });

        if (expErr) throw expErr;

        // Upsert tracking_domain
        const { error: trkErr } = await supabase
            .from('settings')
            .upsert({ key: 'tracking_domain', value: domainVal }, { onConflict: 'key' });

        if (trkErr) throw trkErr;

        return NextResponse.json({ success: true, message: 'Configuration saved successfully!' });
    } catch (e) {
        return NextResponse.json({ success: false, message: e.message }, { status: 500 });
    }
}
