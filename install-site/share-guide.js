// A user-initiated share link. It does not include a visitor ID, letter text,
// email address or any other personal data.
export function buildGuideShareUrl(origin, guidePath) {
  const url = new URL(guidePath, origin);
  url.searchParams.set('utm_source', 'friend_share');
  url.searchParams.set('utm_medium', 'organic');
  return url.toString();
}

export function setupGuideShare({button, status, url, title, text, copiedMessage, manualMessage, shareNavigator = globalThis.navigator, pageDocument = globalThis.document}) {
  if (!button || !status) return;
  button.addEventListener('click', async () => {
    try {
      if (typeof shareNavigator?.share === 'function') {
        await shareNavigator.share({title, text, url});
        status.textContent = '';
        return;
      }
      if (shareNavigator?.clipboard?.writeText) {
        await shareNavigator.clipboard.writeText(url);
        status.textContent = copiedMessage;
        return;
      }
    } catch (error) {
      if (error?.name === 'AbortError') return;
    }
    const link = pageDocument.createElement('a');
    link.href = url;
    link.textContent = url;
    status.replaceChildren(pageDocument.createTextNode(`${manualMessage} `), link);
  });
}
