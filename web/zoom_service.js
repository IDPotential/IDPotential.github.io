
const client = ZoomMtgEmbedded.createClient();

async function initZoom(meetingNumber, password, userName, sdkKey, sdkSecret) {
    // Ensure strict cleanup before trying to initialize a new session
    await leaveZoom();

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
    meetingElement.style.display = 'block'; // Ensure visibility if it was hidden

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
        console.log('Initializing Zoom client...');
        await client.init({
            zoomAppRoot: meetingElement,
            language: 'ru-RU',
            // patchJsMedia: true, // Removed as it might conflict without SharedArrayBuffer
            customize: {
                video: {
                    isResizable: true,
                    poi: { isShow: false },
                    disableVideo: false,
                    viewSizes: {
                        default: {
                            width: 960,
                            height: 540
                        }
                    }
                }
            }
        });

        console.log('Joining Zoom meeting...');
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

        // Re-attach listener only if initialization succeeded
        try {
            // DYNAMIC SCALING LOGIC
            // We forced a large resolution (960x540) to enable Desktop UI features (Gallery View).
            // Now we must scale it down to fit the actual container using CSS transforms.
            const scaleZoomContent = () => {
                const container = findZoomContainer();
                if (!container) return;

                const targetWidth = 960; // Must match the viewSizes we set
                const containerWidth = container.clientWidth || window.innerWidth;

                // If container is smaller than target, we need to shrink (unzoom)
                if (containerWidth < targetWidth) {
                    const scale = containerWidth / targetWidth;

                    // We apply this to the immediate children of the container (the Zoom root)
                    // because applying to container itself might break layout.
                    // Zoom SDK creates a root div like #zmmtg-root inside our container.
                    // However, our container IS the zoomAppRoot passed to init.

                    // NOTE: Zoom SDK modifies the container deeply.
                    // Let's try applying to the container's content via style injection or direct transform
                    // of the Zmmtg root element if accessible, otherwise the container child.

                    // Strategy: Apply zoom/transform to the container's *content*.
                    // The SDK often resets styles. Let's try setting it on the container but compensate size.

                    // Better Strategy: Find #zmmtg-root specifically (it's global usually) or the root child.
                    const zoomRoot = document.getElementById('zmmtg-root') || container.firstElementChild;
                    if (zoomRoot) {
                        zoomRoot.style.transform = `scale(${scale})`;
                        zoomRoot.style.transformOrigin = 'top left';
                        zoomRoot.style.width = `${100 / scale}%`;
                        zoomRoot.style.height = `${100 / scale}%`;
                    }
                }
            };

            // Run once and on resize
            scaleZoomContent();
            window.addEventListener('resize', scaleZoomContent);

            client.on('connection-change', (e) => {
                if (e.state === 'Closed') {
                    const el = findZoomContainer();
                    if (el) {
                        el.innerHTML = '';
                        el.style.display = 'none';
                        window.removeEventListener('resize', scaleZoomContent);
                    }
                }
            });
        } catch (e) { console.warn('Could not attach listener', e); }

    } catch (error) {
        console.error('Zoom join error:', error);
    }
}

function findZoomContainer() {
    // Try global match first
    let element = document.getElementById('zoom-meeting-container');
    if (element) return element;

    // Search in Flutter Platform Views (Shadow DOM)
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
    console.log('Attempting to leave Zoom...');

    // Attempt SDK leave, but don't let it block cleanup
    try {
        if (client && typeof client.leave === 'function') {
            // Give it 1 second to leave gracefully, otherwise force kill
            const leavePromise = client.leave();
            const timeoutPromise = new Promise(resolve => setTimeout(resolve, 1000));
            await Promise.race([leavePromise, timeoutPromise]);
        }
    } catch (error) {
        console.warn('Zoom SDK leave warning (ignoring):', error);
    }

    // FORCE CLEANUP: This is the nuclear option to stop audio.
    const meetingElement = findZoomContainer();
    if (meetingElement) {
        // DO NOT use remove() as it breaks Flutter's Platform View Registry
        meetingElement.innerHTML = '';
        meetingElement.style.display = 'none';

        // Reload to force-kill audio? User requested "exit". 
        // window.location.reload(); // Too aggressive for SPA.
    }

    // Re-finding to clear innerHTML specifically
    const container = document.getElementById('zoom-meeting-container');
    // Note: findZoomContainer handles ShadowDOM, but for 'remove' operations we want to be careful.

    // BETTER APPROACH: Reload the page is the only 100% way if SDK is buggy.
    // But we want to avoid that.

    // Let's try to clear the DOM content aggressively.
    const aggressiveCleanup = findZoomContainer();
    if (aggressiveCleanup) {
        aggressiveCleanup.innerHTML = '';
        aggressiveCleanup.style.display = 'none';

        // Force reload of the window location if we are stuck?
        // No, let's trust that clearing the 'zoomAppRoot' kills the iframe/rendering logic.
    }

    // Explicitly unmount if React was used internally? No access.
    // We will rely on innerHTML = '' hitting the root.
}

window.initZoom = initZoom;
window.leaveZoom = leaveZoom;
