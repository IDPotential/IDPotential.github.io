
const client = ZoomMtgEmbedded.createClient();

async function initZoom(meetingNumber, password, userName, sdkKey, sdkSecret) {
    let meetingElement = document.getElementById('zoom-meeting-container');
    if (!meetingElement) {
        console.error('Zoom container not found');
        return;
    }

    const role = 0; // 0 for attendee, 1 for host (but usually 0 for SDK client)
    const timestamp = Math.round(new Date().getTime() / 1000) - 30;
    
    // Generate Signature (Client-side for now, as requested for "integrated app" feel)
    // Note: In production, this should be done on a backend.
    const msg = btoa(sdkKey + meetingNumber + timestamp + role);
    const hash = sha256.hmac.base64(sdkSecret, msg);
    const signature = btoa(`${sdkKey}.${meetingNumber}.${timestamp}.${role}.${hash}`);

    try {
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            patchJsMedia: true,
            leaveUrl: window.location.origin
        });

        await client.join({
            signature: signature,
            sdkKey: sdkKey,
            meetingNumber: meetingNumber,
            password: password,
            userName: userName,
            userEmail: '',
            tk: ''
        });
        
        console.log('Joined Zoom meeting successfully');
    } catch (error) {
        console.error('Zoom join error:', error);
    }
}

async function leaveZoom() {
    try {
        await client.leave();
        console.log('Left Zoom meeting');
    } catch (error) {
        console.error('Zoom leave error:', error);
    }
}

window.initZoom = initZoom;
window.leaveZoom = leaveZoom;
