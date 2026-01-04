
const client = ZoomMtgEmbedded.createClient();

async function initZoom(meetingNumber, password, userName, sdkKey, sdkSecret) {
    let meetingElement = findZoomContainer();

    // Retry finding container if not found immediately (give it up to 2 seconds)
    if (!meetingElement) {
        for (let i = 0; i < 10; i++) {
            await new Promise(r => setTimeout(r, 200));
            meetingElement = findZoomContainer();
            if (meetingElement) break;
        }
    }

    if (!meetingElement) {
        console.error('Zoom container not found after retries');
        return;
    }

    // Clear previous content if any (important for re-joining)
    meetingElement.innerHTML = '';

    const role = 0;
    const timestamp = Math.round(new Date().getTime() / 1000) - 30;

    const msg = btoa(sdkKey + meetingNumber + timestamp + role);
    const hash = sha256.hmac.base64(sdkSecret, msg);
    const signature = btoa(`${sdkKey}.${meetingNumber}.${timestamp}.${role}.${hash}`);

    try {
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            patchJsMedia: true,
            customize: {
                video: {
                    isResizable: true,
                    viewSizes: {
                        default: {
                            width: 1000,
                            height: 600
                        },
                        ribbon: {
                            width: 300,
                            height: 600
                        }
                    }
                }
            }
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

function findZoomContainer() {
    // Try global match first
    let element = document.getElementById('zoom-meeting-container');
    if (element) return element;

    // Search in Flutter Platform Views (Shadow DOM)
    // Flutter Web typically renders platform views inside <flt-platform-view> elements
    const platformViews = document.querySelectorAll('flt-platform-view');
    for (let view of platformViews) {
        if (view.shadowRoot) {
            element = view.shadowRoot.getElementById('zoom-meeting-container');
            if (element) return element;
        }
    }
    return null;
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
