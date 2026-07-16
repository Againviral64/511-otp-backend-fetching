import supabase, { isMock } from './db';

export async function verifyAuth(request) {
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        throw new Error('Session expired or missing authorization header.');
    }

    const token = authHeader.split(' ')[1];

    if (!supabase) {
        // Mock fallback
        return { id: '00000000-0000-0000-0000-000000000000', email: 'partner@novatix.com', role: 'admin', balance: 3500.0, currency: 'PKR' };
    }

    const { data: { user }, error } = await supabase.auth.getUser(token);
    if (error || !user) {
        console.error('verifyAuth: getUser error:', error ? error.message : 'No user found');
        throw new Error('Invalid token session.');
    }

    // Fetch profile
    let { data: profile, error: profileErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle();

    if (profileErr) {
        console.error('verifyAuth: profiles select database error:', profileErr.message);
    }

    const name = user.user_metadata?.name || 'User';

    if (!profile) {
        console.warn(`verifyAuth: No profile row found for user ${user.id}. Attempting to insert one...`);
        const { data: newProfile, error: insertErr } = await supabase
            .from('profiles')
            .insert([{ id: user.id, email: user.email, name: name, balance: 0.000, spend: 0.000, total_orders: 0, role: 'user', currency: 'PKR', status: 'ACTIVE' }])
            .select()
            .maybeSingle();
        
        if (insertErr) {
            console.error('verifyAuth: profiles insert database error:', insertErr.message);
        }
        profile = newProfile;
    }

    if (profile && (profile.status === 'SUSPENDED' || profile.status === 'BANNED')) {
        console.warn(`verifyAuth: Banned user login attempt blocked for email: ${user.email}`);
        throw new Error('Access Denied: Your account has been suspended or banned. Please contact support.');
    }

    return {
        id: user.id,
        email: user.email,
        name: profile ? (profile.name || name) : name,
        role: profile ? profile.role : 'user',
        balance: profile ? parseFloat(profile.balance) : 0.000,
        currency: profile ? (profile.currency || 'PKR') : 'PKR',
        spend: profile ? parseFloat(profile.spend || 0) : 0.000,
        total_orders: profile ? parseInt(profile.total_orders || 0) : 0
    };
}

export async function verifyAdmin(request) {
    const user = await verifyAuth(request);
    
    if (user.role && user.role.toLowerCase() === 'admin') {
        return user;
    }

    if (isMock || !supabase) {
        throw new Error('Access Denied: Admin authorization required.');
    }

    // Check admin_profiles table
    const { data, error } = await supabase
        .from('admin_profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (data && !error) {
        return user;
    }

    throw new Error('Access Denied: Admin authorization required.');
}
