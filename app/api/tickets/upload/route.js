import { NextResponse } from 'next/server';
import supabase, { isMock } from '@/lib/db';
import { verifyAuth } from '@/lib/middleware';

export async function POST(request) {
    try {
        const user = await verifyAuth(request);
        const formData = await request.formData();
        const file = formData.get('file');

        if (!file) {
            return NextResponse.json({ success: false, message: 'No file uploaded.' });
        }

        // Validate size (< 5MB)
        if (file.size > 5 * 1024 * 1024) {
            return NextResponse.json({ success: false, message: 'File is too large. Max size allowed is 5 MB.' });
        }

        // Validate type
        const allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
        if (!allowedTypes.includes(file.type)) {
            return NextResponse.json({ success: false, message: 'Invalid file type. Only JPG, JPEG, PNG, and WEBP formats are allowed.' });
        }

        const arrayBuffer = await file.arrayBuffer();
        const buffer = Buffer.from(arrayBuffer);

        const fileExt = file.name.split('.').pop();
        const uniqueId = `TKT-${Math.floor(100000 + Math.random() * 900000)}`;
        const filePath = `tickets/${user.id}/${uniqueId}/screenshot.${fileExt}`;

        if (isMock || !supabase) {
            return NextResponse.json({ success: true, filePath: 'mock_proofs/' + filePath });
        }

        const { data, error } = await supabase.storage
            .from('deposit-proofs')
            .upload(filePath, buffer, {
                contentType: file.type,
                duplex: 'half'
            });

        if (error) {
            return NextResponse.json({ success: false, message: 'Supabase upload error: ' + error.message });
        }

        return NextResponse.json({ success: true, filePath });
    } catch (err) {
        return NextResponse.json({ success: false, message: err.message }, { status: 500 });
    }
}
