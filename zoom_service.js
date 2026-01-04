
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

    // Generate JWT Signature using CryptoJS
    // Spec: https://developers.zoom.us/docs/meeting-sdk/auth/#generate-a-signature

    // SPECIFIC FIX: Ensure meetingNumber is a clean integer
    // Remove any non-digits (spaces, dashes) and parse as int
    const mnInt = parseInt(String(meetingNumber).replace(/\D/g, ''), 10);
    const safeSdkKey = sdkKey.trim();
    const safeSdkSecret = sdkSecret.trim();

    const iat = Math.round(new Date().getTime() / 1000) - 30;
    const exp = iat + 60 * 60 * 2;

    const oHeader = { alg: 'HS256', typ: 'JWT' };
    const oPayload = {
        sdkKey: safeSdkKey,
        mn: mnInt,
        role: role,
        iat: iat,
        exp: exp,
        appKey: safeSdkKey,
        tokenExp: exp
    };

    const sHeader = JSON.stringify(oHeader);
    const sPayload = JSON.stringify(oPayload);

    // Helper to base64url encode
    const base64UrlEncode = (str) => {
        const encoded = CryptoJS.enc.Base64.stringify(CryptoJS.enc.Utf8.parse(str));
        return encoded.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    };

    const base64UrlHeader = base64UrlEncode(sHeader);
    const base64UrlPayload = base64UrlEncode(sPayload);

    const signature = CryptoJS.HmacSHA256(base64UrlHeader + "." + base64UrlPayload, sdkSecret);
    const base64UrlSignature = CryptoJS.enc.Base64.stringify(signature)
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');

    const jwtSignature = `${base64UrlHeader}.${base64UrlPayload}.${base64UrlSignature}`;

    try {
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            patchJsMedia: true,
            customize: {
                video: {
                    isResizable: true,
                    poi: { isShow: false },
                    disableVideo: false,
                    viewSizes: {
                        default: {
                            width: 320,
                            height: 180
                        }
                    }
                }
            }
        });

        await client.join({
            signature: jwtSignature,
            sdkKey: safeSdkKey,
            meetingNumber: mnInt,
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
        if (client) {
            await client.leave();
            console.log('Left Zoom meeting');
        }
    } catch (error) {
        console.error('Zoom leave error:', error);
    }

    // Force cleanup DOM
    const meetingElement = findZoomContainer();
    if (meetingElement) {
        meetingElement.innerHTML = '';
    }
}

window.initZoom = initZoom;
window.leaveZoom = leaveZoom;
